'use strict';

// Runs inside actions/github-script's Node runtime; no extra tool installation.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');

const targets = ['windows-x64', 'windows-arm64', 'macos-universal'];

function resolveVersion(pubspec, requested = '') {
  const match = /^version:[ \t]*(\d+\.\d+\.\d+)(?:\+(\d+))?[ \t]*\r?$/m.exec(pubspec);
  if (!match) throw new Error('Missing or invalid pubspec version.');
  const version = requested.trim() || match[1];
  if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error('Use a release version such as 1.0.8.');
  const buildNumber = match[2] || '1';
  const updated = pubspec.replace(match[0], `version: ${version}+${buildNumber}${match[0].endsWith('\r') ? '\r' : ''}`);
  return {version, buildNumber, updated};
}

function render(template, values) {
  return template.replace(/\{\{([A-Z0-9_]+)\}\}/g, (_, key) => {
    if (!Object.hasOwn(values, key)) throw new Error(`Unknown template field: ${key}`);
    return String(values[key]);
  });
}

function git(...args) {
  return execFileSync('git', args, {encoding: 'utf8'}).trim();
}

function prepare({core, context}) {
  const original = fs.readFileSync('pubspec.yaml', 'utf8');
  const {version, buildNumber, updated} = resolveVersion(original, process.env.RELEASE_VERSION);
  if (process.env.UPDATE_PUBSPEC === 'true' && updated !== original) {
    if (!context.ref.startsWith('refs/heads/')) {
      throw new Error('Version commits require a branch. Disable update_pubspec when building a tag.');
    }
    fs.writeFileSync('pubspec.yaml', updated);
    git('config', 'user.name', 'github-actions[bot]');
    git('config', 'user.email', 'github-actions[bot]@users.noreply.github.com');
    git('add', '--', 'pubspec.yaml');
    git('commit', '-m', `chore: update version to ${version}`);
    git('push', 'origin', `HEAD:${context.ref}`);
  }
  core.setOutput('version', version);
  core.setOutput('build_number', buildNumber);
  core.setOutput('sha', git('rev-parse', 'HEAD'));
  core.info(`Release ${version}+${buildNumber}`);
}

function peArchitecture(header) {
  if (header.length < 64 || header.toString('ascii', 0, 2) !== 'MZ') {
    throw new Error('Not a PE binary.');
  }
  const offset = header.readUInt32LE(0x3c);
  if (offset + 6 > header.length || header.readUInt32LE(offset) !== 0x00004550) {
    throw new Error('Invalid PE header.');
  }
  const machine = header.readUInt16LE(offset + 4);
  if (machine === 0x8664) return 'x64';
  if (machine === 0xaa64) return 'arm64';
  throw new Error(`Unsupported PE architecture: 0x${machine.toString(16)}`);
}

function elfArchitecture(header) {
  // Dart stores its Windows AOT snapshot in ELF format, despite the .so file
  // being loaded by a Windows application rather than the OS dynamic linker.
  if (header.length < 20 || header.readUInt32BE(0) !== 0x7f454c46 ||
      header[4] !== 2 || header[5] !== 1) {
    throw new Error('Not a 64-bit little-endian ELF snapshot.');
  }
  const machine = header.readUInt16LE(18);
  if (machine === 62) return 'x64';
  if (machine === 183) return 'arm64';
  throw new Error(`Unsupported ELF architecture: ${machine}`);
}

function* regularFiles(directory) {
  for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
    const fullPath = path.join(directory, entry.name);
    // Do not follow framework symlinks or validate the same file repeatedly.
    if (entry.isDirectory()) yield* regularFiles(fullPath);
    else if (entry.isFile()) yield fullPath;
  }
}

function verifyWindows(directory, arch) {
  const executable = path.join(directory, 'light_novel_image.exe');
  if (!fs.existsSync(executable)) throw new Error(`Missing application: ${executable}`);
  for (const file of regularFiles(directory)) {
    const snapshot = path.basename(file) === 'app.so';
    if (!snapshot && !/\.(exe|dll)$/i.test(file)) continue;
    // Read only the header, not entire multi-megabyte DLLs.
    const header = Buffer.alloc(4096);
    const fd = fs.openSync(file, 'r');
    let size;
    try { size = fs.readSync(fd, header, 0, header.length, 0); }
    finally { fs.closeSync(fd); }
    const actual = (snapshot ? elfArchitecture : peArchitecture)(header.subarray(0, size));
    if (actual !== arch) throw new Error(`Wrong architecture: ${file} is ${actual}, expected ${arch}`);
  }
}

function verifyMacOS(app) {
  if (!fs.existsSync(path.join(app, 'Contents/MacOS/light_novel_image'))) {
    throw new Error('Missing macOS executable.');
  }
  const machOMagic = new Set([0xfeedface, 0xfeedfacf, 0xcefaedfe, 0xcffaedfe,
    0xcafebabe, 0xbebafeca, 0xcafebabf, 0xbfbafeca]);
  let count = 0;
  for (const file of regularFiles(app)) {
    const header = Buffer.alloc(4);
    const fd = fs.openSync(file, 'r');
    let size;
    try { size = fs.readSync(fd, header, 0, 4, 0); }
    finally { fs.closeSync(fd); }
    if (size === 4 && machOMagic.has(header.readUInt32BE(0))) {
      execFileSync('lipo', ['-verify_arch', 'x86_64', 'arm64', file], {stdio: 'inherit'});
      count++;
    }
  }
  if (count < 3) throw new Error('Application and Flutter frameworks were not found.');
  execFileSync('codesign', ['--verify', '--deep', '--strict', app], {stdio: 'inherit'});
}

async function sha256(file) {
  const hash = crypto.createHash('sha256');
  for await (const chunk of fs.createReadStream(file)) hash.update(chunk);
  return hash.digest('hex');
}

async function packageApp({core, context, manual = false}) {
  const arch = process.env.PACKAGE_ARCH;
  const platform = manual ? 'windows' : process.env.PACKAGE_PLATFORM;
  const target = `${platform}-${arch}`;
  if (!targets.includes(target)) throw new Error(`Unsupported package target: ${target}`);
  const {version} = resolveVersion(fs.readFileSync('pubspec.yaml', 'utf8'), process.env.RELEASE_VERSION);
  const mode = manual ? process.env.BUILD_TYPE : 'release';
  if (!['release', 'debug'].includes(mode)) throw new Error('Unsupported build type.');
  const name = manual ? `light_novel_image-${mode}-${target}-${context.runId}-${process.env.GITHUB_RUN_ATTEMPT || '1'}`
    : `light_novel_image-v${version}-${target}`;
  const dist = path.resolve('dist');
  const staging = path.resolve('build/release-package', name);
  if (fs.existsSync(staging)) throw new Error(`Package staging directory already exists: ${staging}`);
  fs.mkdirSync(dist, {recursive: true});
  fs.mkdirSync(staging, {recursive: true});
  if (platform === 'windows') {
    const source = path.resolve(`build/windows/${arch}/runner/${mode === 'release' ? 'Release' : 'Debug'}`);
    verifyWindows(source, arch);
    fs.cpSync(source, staging, {recursive: true});
  } else {
    const source = path.resolve('build/macos/Build/Products/Release/light_novel_image.app');
    verifyMacOS(source);
    execFileSync('ditto', [source, path.join(staging, 'light_novel_image.app')], {stdio: 'inherit'});
  }
  const suffix = process.env.PACKAGE_LANGUAGE === 'en' ? '_EN' : '';
  const template = fs.readFileSync(`.github/templates/README_${platform.toUpperCase()}${suffix}.txt`, 'utf8');
  fs.writeFileSync(path.join(staging, 'README.txt'), render(template, {
    VERSION: version, ARCH: arch, REPOSITORY: `${context.repo.owner}/${context.repo.repo}`,
    BUILD_TIME: new Date().toISOString(),
  }));
  const zip = path.join(dist, `${name}.zip`);
  if (fs.existsSync(zip)) throw new Error(`Package already exists: ${zip}`);
  if (platform === 'windows') {
    execFileSync('pwsh', ['-NoProfile', '-Command',
      "$ErrorActionPreference = 'Stop'; Compress-Archive -Path (Join-Path $env:PACKAGE_STAGING '*') -DestinationPath $env:PACKAGE_ZIP -CompressionLevel Fastest"],
    {stdio: 'inherit', env: {...process.env, PACKAGE_STAGING: staging, PACKAGE_ZIP: zip}});
  } else {
    // Store executable bits and framework symlinks, without archive/export rebuilds.
    execFileSync('zip', ['-q', '-r', '-y', '-1', zip, '.'], {cwd: staging, stdio: 'inherit'});
  }
  fs.writeFileSync(`${zip}.sha256`, `${await sha256(zip)}  ${name}.zip\n`);
  core.setOutput('name', name);
  core.info(`Packaged ${name}`);
}

async function collectPackages(directory, version) {
  const packages = [];
  const expected = targets.map(target => `light_novel_image-v${version}-${target}.zip`);
  const actual = fs.readdirSync(directory).filter(file => file.endsWith('.zip')).sort();
  if (actual.join('\n') !== [...expected].sort().join('\n')) {
    throw new Error(`Expected exactly three release ZIPs: ${expected.join(', ')}`);
  }
  for (const name of expected) {
    const file = path.join(directory, name);
    const checksum = await sha256(file);
    const record = fs.readFileSync(`${file}.sha256`, 'utf8').trim();
    if (record !== `${checksum}  ${name}`) throw new Error(`SHA256 mismatch: ${name}`);
    packages.push({name, checksum});
  }
  return packages;
}

async function releaseBody({context}) {
  const {version} = resolveVersion(fs.readFileSync('pubspec.yaml', 'utf8'), process.env.RELEASE_VERSION);
  const packages = await collectPackages('artifacts', version);
  const repository = `${context.repo.owner}/${context.repo.repo}`;
  const values = {VERSION: version, REPOSITORY: repository, BUILD_TIME: new Date().toISOString()};
  packages.forEach(({name, checksum}, index) => {
    const key = targets[index].replaceAll('-', '_').toUpperCase();
    values[`${key}_ZIP`] = name;
    values[`${key}_URL`] = `${context.serverUrl || 'https://github.com'}/${repository}/releases/download/v${version}/${name}`;
    values[`${key}_SHA256`] = checksum;
  });
  const suffix = process.env.PACKAGE_LANGUAGE === 'en' ? '_EN' : '';
  fs.writeFileSync('release_body.md', render(fs.readFileSync(`.github/templates/RELEASE_BODY${suffix}.txt`, 'utf8'), values));
  fs.writeFileSync('artifacts/SHA256SUMS.txt', packages.map(({name, checksum}) => `${checksum}  ${name}\n`).join(''));
}

module.exports = {targets, resolveVersion, render, prepare, peArchitecture, elfArchitecture, verifyWindows,
  verifyMacOS, sha256, packageApp, collectPackages, releaseBody};
