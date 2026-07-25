# 轻小说图片浏览器 📚

一个轻小说的EPUB图片浏览器，采用Flutter开发，支持Windows、macOS和Linux桌面平台。

[![Flutter](https://img.shields.io/badge/flutter-3.44.8-blue)](https://flutter.dev/)
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

## 🎬 演示

![应用演示](doc/demo.gif)

## 🚀 快速开始

### 📥 下载预构建版本（推荐）

如果您只想使用应用而不进行开发，可以直接下载预构建的版本：

1. **前往 [Releases 页面](https://github.com/dccif/light_novel_image/releases/latest)**
2. **下载最新的 `light_novel_image-v*-windows-x64.zip`**
3. **解压并运行 `light_novel_image.exe`**

> 💡 预构建版本会在每次代码更新后自动构建，无需安装Flutter开发环境。

### 🛠️ 开发环境搭建

### 环境要求

- Flutter SDK 3.44.8 或更高版本
- Dart SDK 3.12.2 或更高版本
- 理论上支持的操作系统：Windows 10+、macOS 10.14+、Linux (Ubuntu 18.04+)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/your-username/light_novel_image.git
   cd light_novel_image
   ```

2. **安装依赖**
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

# macOS
flutter build macos

# Linux
flutter build linux
```

## 📖 使用说明

1. **启动应用** - 双击运行构建好的可执行文件
2. **导入EPUB** - 将EPUB文件拖拽到应用窗口，或点击选择文件
3. **浏览图片** - 在图片浏览器中查看和缩放图片
4. **阅读图片上下文** - 在查看器中阅读完整 EPUB 正文；“图片原文位置”会标示当前图片所在位置
5. **快速返回位置** - 原文位置不在可视范围时，点击右下角悬浮图标即可返回
6. **批量处理** - 可同时选择多个EPUB文件进行处理

## 🛠️ 技术栈

- **当前版本**: 1.0.7
- **Framework**: Flutter 3.44.8 / Dart 3.12.2
- **UI库**: Fluent UI (Windows风格界面)
- **路由**: GoRouter
- **文件处理**: 
  - `desktop_drop` - 拖拽文件支持
  - `file_picker` - 文件选择
  - `archive` - EPUB文件解压
- **图片查看**: Extended Image（缩放、平移与图片切换）
- **EPUB 解析**: Archive + XML（OPF、spine、导航目录与 XHTML 正文）
- **窗口管理**: Window Manager + Flutter Acrylic

## 🙏 致谢

感谢以下开源项目的支持：
- [Flutter](https://flutter.dev/)
- [Fluent UI](https://pub.dev/packages/fluent_ui)
- [PhotoView](https://pub.dev/packages/photo_view)
- [Window Manager](https://pub.dev/packages/window_manager)
---

⭐ 如果这个项目对你有帮助，请给它一个星标！
