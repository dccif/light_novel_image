# GitHub Actions 构建说明

所有工作流均由 Actions 页面手动触发，不会在普通 push、创建 tag 或 Release 时自动运行。macOS 需要 12.0+，Windows 不支持 32 位 x86。

## 发布三个安装包

进入 Actions → Release Build → Run workflow，输入版本号（如 `1.0.8`），选择说明语言以及是否创建草稿。

| 安装包 | 运行器 | 适用处理器 |
| --- | --- | --- |
| `light_novel_image-v1.0.8-windows-x64.zip` | `windows-2025` | Intel / AMD x64 |
| `light_novel_image-v1.0.8-windows-arm64.zip` | `windows-11-arm` | Windows ARM64 |
| `light_novel_image-v1.0.8-macos-universal.zip` | `macos-26-intel` | Intel / Apple Silicon |

Windows 必须在 Windows 上构建，macOS 必须在 macOS 上构建；Flutter 的跨平台 UI 不代表能从 Linux 交叉编译所有桌面平台。Linux 只负责版本准备、静态分析、测试和汇总发布。

- `update_pubspec` 开启时，准备任务只提交一次版本修改，保留 `+3` 等构建号；仓库需允许 Actions 写入，受保护分支可能拒绝提交。关闭后仍通过构建参数设置发布版本，但不会修改源码版本。
- 三个构建检出相同的提交 SHA，新建的发布 tag 也指向该 SHA。已存在的 tag 不会被强制移动，发布新代码请使用新的版本号。输入版本仅接受 `数字.数字.数字`。
- Windows 会校验 EXE / DLL 的 PE 架构及 Dart AOT 快照的 ELF 架构；macOS 会校验主程序、Flutter 框架及所有 Mach-O 插件均包含 x86_64 和 arm64，并检查临时签名。
- ZIP 内包含安装说明。发布前再次计算 SHA256，必须三个包齐全且校验匹配，随后上传 ZIP 与 `SHA256SUMS.txt`。
- 发布构建的 Actions 中间产物保留 90 天；Release 资产不受这个保留期影响。草稿需确认后手动发布。

## 加速构建

- 共用 [setup-flutter](../actions/setup-flutter/action.yml) 配置，Flutter 固定为 `3.47.6`，升级时只需修改这一处，并同步 `pubspec.yaml` 和项目 README。
- 使用 `subosito/flutter-action@v2` 缓存 Flutter SDK 和 pub 依赖；使用 `actions/cache@v5` 缓存 CocoaPods 和 `.dart_tool/flutter_build`。缓存按系统、运行器架构、Flutter 版本、依赖、原生配置和构建参数隔离，源码变更时仍执行真实构建。
- macOS 从原来的两套架构任务、预编译、archive / export，改为一次 `flutter build macos --release --no-pub` 生成通用应用。Windows 两个原生架构并行构建。
- ZIP 使用快速压缩，`upload-artifact@v6` 设置 `compression-level: 0`，不对已压缩文件重复压缩；汇总下载使用 `download-artifact@v8`，发布使用 `softprops/action-gh-release@v3`。
- 不缓存整个原生 build 目录，也不跳过 Flutter 构建；避免大缓存上传成本和旧产物误发布。没有给 MSBuild 添加不生效的 CMake compiler launcher。

首次运行、依赖升级或缓存失效仍需要下载与完整编译；GitHub 运行器排队不属于编译耗时，固定 Intel macOS 标签并不能保证没有排队。通用包需要编译两种 macOS 架构，但只启动一台 macOS 运行器。

### Windows ARM64 SDK

Flutter 3.47.6 的官方 Windows 发布清单只有 x64 SDK 包。共用 Action 先安装这个包，再在 ARM64 运行器上调用 Flutter 自带的更新逻辑获取与引擎匹配的 ARM64 Dart SDK。SDK 缓存按真实运行器架构隔离，避免污染 x64 缓存；若 Dart 没有切换到 `windows_arm64`，任务直接失败，不会将 x64 产物标成 ARM64。

## 测试或临时构建

- Flutter Analysis and Tests：在 `ubuntu-24.04` 上按选项运行 `flutter analyze --no-pub` 和 `flutter test --no-pub`，并验证发布工具。
- Manual Build：选择 Windows x64 / ARM64 和 Debug / Release；复用同一套环境配置及架构校验，产物保留 7 天，不创建 Release。

发布工具本地验证：

```powershell
mise exec -- node --test .github/scripts/release.test.cjs
```

## 常见问题

- `SHA256 mismatch` / 缺少安装包：查看对应构建任务，不要绕过汇总校验。
- ARM64 插件校验失败：依赖的原生 DLL 不是 ARM64，需要更新或更换插件，而不是修改文件名。
- macOS 架构缺失：检查插件支持和 `EXCLUDED_ARCHS`，不要发布单架构应用作为通用包。
- 缓存异常：在 Actions → Caches 删除对应平台缓存后重跑；若修改缓存结构，将共用 Action 的 `v1` 提升到新版本。
- macOS 首次启动被阻止：应用只有临时签名，未签署 Developer ID、未公证；通过系统隐私与安全性设置允许打开，正式签名需另行配置证书。

参考：[GitHub 运行器](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)、[Flutter 支持平台](https://docs.flutter.dev/reference/supported-platforms)。
