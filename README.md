# 轻小说图片浏览器 📚

一个轻小说的EPUB图片浏览器，采用Flutter开发，支持Windows、macOS和Linux桌面平台。

## ✨ 功能特性

- 🖼️ **专业图片浏览** - 专为EPUB文件中的图片展示而优化
- 🎨 **现代UI设计** - 采用Fluent UI设计语言，提供原生Windows体验
- 🖱️ **拖拽操作** - 支持直接拖拽EPUB文件到应用窗口
- 📁 **批量处理** - 同时打开多个EPUB文件
- 🔍 **图片缩放** - 内置图片查看器，支持缩放和平移

## 🎬 演示

![应用演示](doc/demo.gif)

## 🚀 快速开始

### 环境要求

- Flutter SDK 3.32.1 或更高版本
- Dart SDK
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
4. **批量处理** - 可同时选择多个EPUB文件进行处理

## 🛠️ 技术栈

- **Framework**: Flutter 3.32.1
- **UI库**: Fluent UI (Windows风格界面)
- **路由**: GoRouter
- **文件处理**: 
  - `desktop_drop` - 拖拽文件支持
  - `file_picker` - 文件选择
  - `archive` - EPUB文件解压
- **图片查看**: PhotoView
- **窗口管理**: Window Manager + Flutter Acrylic

## 🙏 致谢

感谢以下开源项目的支持：
- [Flutter](https://flutter.dev/)
- [Fluent UI](https://pub.dev/packages/fluent_ui)
- [PhotoView](https://pub.dev/packages/photo_view)
- [Window Manager](https://pub.dev/packages/window_manager)
---

⭐ 如果这个项目对你有帮助，请给它一个星标！
