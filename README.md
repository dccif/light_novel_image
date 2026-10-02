# 轻小说图片浏览器 📚

一个轻小说的EPUB图片浏览器，采用Flutter开发，支持Windows、macOS和Linux桌面平台。

[![Flutter](https://img.shields.io/badge/flutter-3.47.6-blue)](https://flutter.dev/)
[![Latest Release](https://img.shields.io/github/v/release/dccif/light_novel_image?include_prereleases)](https://github.com/dccif/light_novel_image/releases/latest)
[![License](https://img.shields.io/github/license/dccif/light_novel_image)](https://github.com/dccif/light_novel_image/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%7CMacOS-lightgrey)](https://github.com/dccif/light_novel_image)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)](https://dart.dev/)
[![Code size](https://img.shields.io/github/languages/code-size/dccif/light_novel_image)](https://github.com/dccif/light_novel_image)

## ✨ 功能特性

- 🖼️ **专业图片浏览** - 专为EPUB文件中的图片展示而优化
- 🎨 **现代UI设计** - 采用Fluent UI设计语言，提供原生Windows体验
- 🖱️ **拖拽操作** - 支持直接拖拽EPUB文件到应用窗口
- 📁 **批量处理** - 同时打开多个EPUB文件
- 🔍 **图片缩放** - 内置图片查看器，支持缩放和平移
- 📖 **图片原文上下文** - 查看图片时可阅读该图片在 EPUB 正文中的原文位置，并可继续滚动阅读整本书
- 📍 **原文位置定位** - 清晰标记图片原文位置；离开可视范围后可一键返回
- ⌨️ **快捷键导航** - 无论焦点位于图片或原文面板，均可使用左右方向键切换图片
- ⚡ **低内存浏览** - 缩略图按显示像素解码，大书图片按需读取，正文按段落懒布局

## 🎬 演示

![应用演示](doc/demo.gif)

## 📝 更新日志

最新版本 **1.0.8**：优化大书浏览与内存占用，改善原文阅读和键盘切图体验。详见 [更新日志](CHANGELOG.md)。

## 🚀 快速开始

### 📥 下载预构建版本（推荐）

如果您只想使用应用而不进行开发，可以直接下载预构建的版本：

1. **前往 [Releases 页面](https://github.com/dccif/light_novel_image/releases/latest)**
2. **根据处理器选择 Windows x64 / ARM64 包，或 macOS 通用包（Intel 与 Apple Silicon 共用）**
3. **Windows 完整解压后运行 `light_novel_image.exe`；macOS 解压后将 `.app` 放入「应用程序」**

> 💡 发布包由维护者手动触发 GitHub Actions 构建；使用时无需安装 Flutter。Windows 不支持 32 位 x86，macOS 需要 12.0 或更高版本。

### 🛠️ 开发环境搭建

### 环境要求

- Flutter SDK 3.47.6 或更高版本
- Dart SDK 3.13.5 或更高版本
- 桌面平台：Windows 10+（x64 / ARM64）、macOS 12.0+（Intel / Apple Silicon）；Linux 可在对应系统自行构建

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/your-username/light_novel_image.git
   cd light_novel_image
   ```

2. **安装依赖**
   本地 Flutter 通过 mise 管理，可先执行 `mise install flutter@latest`，再使用 `mise exec -- flutter pub get`。CI 固定使用 Flutter 3.47.6，以便复现构建结果。

   ```bash
   flutter pub get
   ```

3. **运行应用**
   ```bash
   flutter run
   ```

### 构建发布版本

```bash
# Windows
flutter build windows

# macOS（在 macOS 上构建通用包）
flutter config --no-enable-macos-arm64-only
flutter build macos --release

# Linux
flutter build linux
```

CI 产出 Windows x64、Windows ARM64 和 macOS Universal 三个包，复用 Flutter / pub / CocoaPods / Dart 构建缓存，每个目标只编译一次。配置与排错见 [构建工作流说明](.github/workflows/README.md)。

## 📖 使用说明

1. **启动应用** - 双击运行构建好的可执行文件
2. **导入EPUB** - 将EPUB文件拖拽到应用窗口，或点击选择文件
3. **浏览图片** - 在图片浏览器中查看和缩放图片
4. **阅读图片上下文** - 在查看器中阅读完整 EPUB 正文；“图片原文位置”会标示当前图片所在位置
5. **快速返回位置** - 原文位置不在可视范围时，点击右下角悬浮图标即可返回
6. **批量处理** - 可同时选择多个EPUB文件进行处理

## 🛠️ 技术栈

- **当前版本**: 1.0.8
- **Framework**: Flutter 3.47.6 / Dart 3.13.5
- **UI库**: Fluent UI (Windows风格界面)
- **路由**: GoRouter
- **文件处理**: 
  - `desktop_drop` - 拖拽文件支持
  - `file_picker` - 文件选择
  - `archive` - EPUB文件解压
- **图片查看**: Extended Image（缩放、平移与图片切换）
- **EPUB 解析**: Archive + XML（OPF、spine、导航目录与 XHTML 正文）
- **窗口管理**: Window Manager + Flutter Acrylic

## ⚡ 性能与缓存

EPUB 通过文件流读取，每个 XHTML 只解析一次，图片尺寸也在同一次后台导入中读取。图片、名称、书籍归属、尺寸和上下文统一存储，排序仅维护一份索引。

- 小书图片共用 **16 MiB** 编码字节预算；超过剩余预算的书籍图片落盘、按需读取。
- 文件图片使用 **32 MiB / 32 项** LRU，并合并同图的并发读取。
- Flutter 解码图片缓存上限为 **64 MiB / 80 项**；查看器仅预加载相邻图片，离开页面释放缓存。
- 正文保留整本书，按可见段落排版，初始位置直接对齐图片标记，支持向前/向后阅读和文本选择。
- 导入缓存按会话隔离；剪贴板及外部查看器的导出文件独立保留，新会话会清理超过七天的旧导出目录。

这些是缓存预算，**不是进程总内存上限**；可见原图、正文、解码临时数据及 GPU 纹理仍会额外占用内存。

验证命令与优化前后合成测量详见 [性能报告](docs/2026-10-02_performance-light-novel-image-report.md)。

```powershell
mise exec -- flutter analyze
mise exec -- flutter test
mise exec -- flutter test tool/benchmarks/context_performance_test.dart
mise exec -- flutter build windows --release
```

## 🙏 致谢

感谢以下开源项目的支持：

- [Flutter](https://flutter.dev/)
- [Fluent UI](https://pub.dev/packages/fluent_ui)
- [Extended Image](https://pub.dev/packages/extended_image)
- [Window Manager](https://pub.dev/packages/window_manager)
---

⭐ 如果这个项目对你有帮助，请给它一个星标！
