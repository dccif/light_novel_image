'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {targets, resolveVersion, render, peArchitecture, elfArchitecture, sha256, collectPackages, verifyWindows, verifyMacOS} = require('./release.cjs');

test('version overrides retain the build number and CRLF', () => {
  const result = resolveVersion('name: app\r\nversion: 1.0.8+3\r\n', '1.0.9');
  assert.equal(result.version, '1.0.9');
  assert.equal(result.buildNumber, '3');
  assert.equal(result.updated, 'name: app\r\nversion: 1.0.9+3\r\n');
});

test('version defaults and invalid inputs', () => {
  assert.equal(resolveVersion('version: 1.0.8').buildNumber, '1');
  assert.equal(resolveVersion('version: 1.0.8+3\n').version, '1.0.8');
  for (const invalid of ['../1.0.9', '1.0.9; echo bad', '1.0.9\nextra', 'v1.0.9']) {
    assert.throws(() => resolveVersion('version: 1.0.8+3', invalid));
  }
  assert.throws(() => resolveVersion('name: app'));
});

test('template values are literal and unknown fields fail', () => {
  assert.equal(render('{{VERSION}}/{{VERSION}}', {VERSION: '$&'}), '$&/$&');
  assert.throws(() => render('{{MISSING}}', {}));
});

function pe(machine) {
  const buffer = Buffer.alloc(512);
  buffer.write('MZ');
  buffer.writeUInt32LE(0x80, 0x3c);
  buffer.writeUInt32LE(0x00004550, 0x80);
  buffer.writeUInt16LE(machine, 0x84);
  return buffer;
}

test('PE architecture verification rejects x86 and corrupt headers', () => {
  assert.equal(peArchitecture(pe(0x8664)), 'x64');
  assert.equal(peArchitecture(pe(0xaa64)), 'arm64');
  assert.throws(() => peArchitecture(pe(0x014c)));
  assert.throws(() => peArchitecture(Buffer.alloc(4)));
  const corrupt = pe(0x8664);
  corrupt.writeUInt32LE(9999, 0x3c);
  assert.throws(() => peArchitecture(corrupt));
});

test('Windows packages reject a mismatched native plugin', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'release-pe-test-'));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  fs.writeFileSync(path.join(directory, 'light_novel_image.exe'), pe(0xaa64));
  fs.writeFileSync(path.join(directory, 'plugin.dll'), pe(0x8664));
  assert.throws(() => verifyWindows(directory, 'arm64'), /Wrong architecture/);
  fs.writeFileSync(path.join(directory, 'plugin.dll'), pe(0xaa64));
  assert.doesNotThrow(() => verifyWindows(directory, 'arm64'));
});

test('ELF AOT snapshots must match the Windows package architecture', t => {
  const header = Buffer.alloc(64);
  header.writeUInt32BE(0x7f454c46, 0);
  header[4] = 2;
  header[5] = 1;
  header.writeUInt16LE(62, 18);
  assert.equal(elfArchitecture(header), 'x64');
  header.writeUInt16LE(183, 18);
  assert.equal(elfArchitecture(header), 'arm64');
  assert.throws(() => elfArchitecture(Buffer.alloc(64)));
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'release-aot-test-'));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  fs.writeFileSync(path.join(directory, 'light_novel_image.exe'), pe(0x8664));
  fs.writeFileSync(path.join(directory, 'app.so'), header);
  assert.throws(() => verifyWindows(directory, 'x64'), /Wrong architecture/);
  header.writeUInt16LE(62, 18);
  fs.writeFileSync(path.join(directory, 'app.so'), header);
  assert.doesNotThrow(() => verifyWindows(directory, 'x64'));
});

function macOSFixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'release-macos-test-'));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  const app = path.join(directory, 'Application with spaces.app');
  const binaries = [
    'Contents/MacOS/light_novel_image',
    'Contents/Frameworks/App.framework/Versions/A/App',
    'Contents/Frameworks/FlutterMacOS.framework/Versions/A/FlutterMacOS',
  ].map(file => path.join(app, file));
  const header = Buffer.alloc(32);
  header.writeUInt32BE(0xcafebabe, 0);
  for (const file of binaries) {
    fs.mkdirSync(path.dirname(file), {recursive: true});
    fs.writeFileSync(file, header);
  }
  return {app, binaries};
}

test('macOS lipo puts the file before -verify_arch, including paths with spaces', t => {
  const {app, binaries} = macOSFixture(t);
  const checked = [];
  let signatureChecked = false;
  verifyMacOS(app, (command, args) => {
    if (command === 'lipo') {
      assert.ok(binaries.includes(args[0]));
      assert.deepEqual(args.slice(1), ['-verify_arch', 'x86_64', 'arm64']);
      checked.push(args[0]);
    } else {
      assert.equal(command, 'codesign');
      assert.deepEqual(args, ['--verify', '--deep', '--strict', app]);
      signatureChecked = true;
    }
  });
  assert.deepEqual(checked.sort(), [...binaries].sort());
  assert.ok(signatureChecked);
});

test('macOS still rejects a framework missing a required architecture', t => {
  const {app} = macOSFixture(t);
  const missing = new Error('App.framework is missing arm64');
  let signatureChecked = false;
  assert.throws(() => verifyMacOS(app, (command) => {
    if (command === 'lipo') throw missing;
    signatureChecked = true;
  }), error => error === missing);
  assert.equal(signatureChecked, false);
});

test('both languages render all release and installation templates', () => {
  const values = {VERSION: '1.0.8', ARCH: 'arm64', REPOSITORY: 'dccif/light_novel_image', BUILD_TIME: '2026-10-02'};
  for (const target of targets) {
    const key = target.replaceAll('-', '_').toUpperCase();
    for (const field of ['ZIP', 'URL', 'SHA256']) values[`${key}_${field}`] = 'test-value';
  }
  for (const suffix of ['', '_EN']) {
    for (const template of ['RELEASE_BODY', 'README_WINDOWS', 'README_MACOS']) {
      const source = fs.readFileSync(`.github/templates/${template}${suffix}.txt`, 'utf8');
      assert.ok(!render(source, values).includes('{{'));
    }
  }
});

test('release aggregation requires exactly three packages and matching SHA256', async t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'release-artifact-test-'));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  for (const target of targets) {
    const name = `light_novel_image-v1.0.8-${target}.zip`;
    const file = path.join(directory, name);
    fs.writeFileSync(file, target);
    fs.writeFileSync(`${file}.sha256`, `${await sha256(file)}  ${name}\n`);
  }
  assert.equal((await collectPackages(directory, '1.0.8')).length, 3);
  const first = path.join(directory, 'light_novel_image-v1.0.8-windows-x64.zip');
  fs.writeFileSync(first, 'tampered');
  await assert.rejects(collectPackages(directory, '1.0.8'), /SHA256 mismatch/);
  fs.rmSync(first);
  await assert.rejects(collectPackages(directory, '1.0.8'), /exactly three/);
});
