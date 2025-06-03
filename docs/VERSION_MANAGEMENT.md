# 版本号管理指南

本文档说明如何管理项目的版本号和发布流程。

## 🔄 版本号管理策略

项目采用以下版本号管理策略：

1. **Git Tag 为权威版本源** - 所有版本发布以Git标签为准
2. **语义化版本** - 使用 `x.y.z` 格式的语义化版本号
3. **自动同步** - pubspec.yaml 会自动同步版本号
4. **自动构建** - 推送标签后自动触发多平台构建和发布

## 📋 版本号优先级

GitHub Actions 按以下优先级获取版本号：

1. **Git Tag** (最高优先级) - 当通过推送标签触发时
2. **手动输入** - 当手动触发工作流时输入的版本号
3. **pubspec.yaml** - 从 pubspec.yaml 文件中解析的版本号

## 🚀 发布新版本

### 方法一：使用自动化脚本 (推荐)

#### macOS/Linux:
```bash
# 更新到版本 1.2.0
./scripts/update_version.sh 1.2.0
```

#### Windows:
```cmd
# 更新到版本 1.2.0
scripts\update_version.bat 1.2.0
```

脚本会自动执行以下操作：
1. ✅ 验证版本号格式
2. ✅ 检查工作区状态
3. ✅ 更新 pubspec.yaml
4. ✅ 创建提交和标签
5. ✅ 推送到远程仓库
6. ✅ 触发自动构建

### 方法二：手动操作

1. **更新 pubspec.yaml**:
   ```yaml
   version: 1.2.0+1  # 更新版本号
   ```

2. **提交更改**:
   ```bash
   git add pubspec.yaml
   git commit -m "chore: bump version to 1.2.0"
   ```

3. **创建标签**:
   ```bash
   git tag -a v1.2.0 -m "Release version 1.2.0"
   ```

4. **推送到远程**:
   ```bash
   git push origin main
   git push origin v1.2.0
   ```

### 方法三：手动触发 GitHub Actions

1. 访问 [Actions 页面](../../actions/workflows/release.yml)
2. 点击 "Run workflow"
3. 输入版本号和其他选项
4. 点击 "Run workflow"

## 🔧 GitHub Actions 配置

### 触发条件

工作流支持两种触发方式：

1. **自动触发** - 推送以 `v` 开头的标签
   ```bash
   git push origin v1.2.0
   ```

2. **手动触发** - 在 GitHub 网页界面手动运行

### 配置选项

手动触发时可以配置：
- **版本号** - 发布的版本号
- **语言** - README 语言 (中文/英文)
- **草稿版本** - 是否创建草稿版本
- **同步 pubspec** - 是否同步更新 pubspec.yaml

## 📦 构建产物

每次发布会自动构建：
- **Windows x64** 版本
- **macOS Universal** 版本 (支持 Intel 和 Apple Silicon)

## 🔍 版本号格式

### 语义化版本

使用 [语义化版本](https://semver.org/) 规范：

- **MAJOR.MINOR.PATCH** (例如: 1.2.0)
  - **MAJOR**: 不兼容的 API 修改
  - **MINOR**: 向下兼容的功能性新增
  - **PATCH**: 向下兼容的问题修正

### pubspec.yaml 格式

```yaml
version: 1.2.0+1
#        ^^^^^ ^^
#        |     |
#        |     +-- Build number (Flutter 构建号)
#        +-------- Version name (应用版本号)
```

## 🛠️ 故障排除

### 常见问题

1. **标签已存在**
   ```bash
   # 删除本地标签
   git tag -d v1.2.0
   
   # 删除远程标签 (谨慎操作)
   git push origin :refs/tags/v1.2.0
   ```

2. **工作区不干净**
   ```bash
   # 查看状态
   git status
   
   # 提交或暂存更改
   git add .
   git commit -m "fix: update before version bump"
   ```

3. **权限问题**
   ```bash
   # 确保脚本有执行权限
   chmod +x scripts/update_version.sh
   ```

### 验证发布

发布后可以通过以下方式验证：

1. **检查 Release 页面**: [Releases](../../releases)
2. **查看 Actions 状态**: [Actions](../../actions)
3. **下载测试包**: 验证构建产物是否正常

## 📝 最佳实践

1. **在功能分支上开发**, 不要直接在 main 分支创建版本标签
2. **发布前测试**, 确保功能正常工作
3. **编写 Release Notes**, 在标签消息中描述主要变更
4. **遵循语义化版本**, 根据变更类型选择合适的版本号递增方式
5. **定期清理**, 删除不需要的预发布版本和草稿

## 🔗 相关链接

- [语义化版本规范](https://semver.org/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Flutter 版本管理](https://flutter.dev/docs/deployment) 