# GitHub Actions 工作流说明

本项目包含以下自动化构建工作流：

## 🔄 工作流类型

### 1. `build-windows.yml` - 持续集成构建
- **触发条件**: 推送到 main/master 分支、创建标签、Pull Request
- **功能**: 自动构建、测试、分析代码，并上传构建产物
- **产物保留**: 30天
- **自动发布**: 当推送标签时自动创建GitHub Release

### 2. `release.yml` - 正式发布构建  
- **触发条件**: 创建GitHub Release 或 手动触发
- **功能**: 构建发布版本，包含详细的安装说明和文件校验
- **产物保留**: 90天
- **特色**: 包含SHA256校验、自动生成README.txt

### 3. `manual-build.yml` - 手动构建
- **触发条件**: 仅手动触发
- **功能**: 快速构建测试版本（支持Debug/Release）
- **产物保留**: 7天
- **用途**: 开发测试使用

## 🚀 使用方法

### 自动构建
1. 推送代码到main分支 → 自动触发CI构建
2. 创建标签 `git tag v1.0.0 && git push origin v1.0.0` → 自动发布

### 手动发布
1. 进入GitHub仓库 → Actions标签页
2. 选择"Release Build"工作流
3. 点击"Run workflow"
4. 输入版本号（如：1.0.0）
5. 点击"Run workflow"开始构建

### 快速测试构建
1. 进入GitHub仓库 → Actions标签页  
2. 选择"Manual Build"工作流
3. 选择构建类型（Release/Debug）
4. 点击"Run workflow"

## 📦 构建产物

### 文件结构
```
light_novel_image-v1.0.0-windows-x64.zip
├── light_novel_image.exe          # 主程序
├── flutter_windows.dll            # Flutter运行时
├── data/                          # 应用数据
│   ├── icudtl.dat
│   └── flutter_assets/
├── README.txt                     # 安装说明
└── 其他依赖文件...
```

### 下载方式
- **Artifacts**: 在Actions页面下载（需要登录GitHub）
- **Releases**: 在Releases页面下载（公开访问）

## 🔧 配置说明

### Flutter版本
- 当前使用: `3.32.1`
- 渠道: `stable`
- 支持缓存以加速构建

### 构建环境
- 运行器: `windows-latest`
- 启用Windows桌面支持
- 自动安装依赖

## 📝 自定义配置

如需修改构建配置，可以编辑相应的`.yml`文件：

- 修改Flutter版本: 更改`flutter-version`字段
- 调整保留天数: 修改`retention-days`值
- 添加构建步骤: 在`steps`中添加新的步骤

## 🔒 权限要求

工作流需要以下权限：
- `contents: read` - 读取仓库内容
- `actions: read` - 读取Actions
- `packages: write` - 写入包（如果需要）

GitHub Actions会自动提供`GITHUB_TOKEN`用于发布。 