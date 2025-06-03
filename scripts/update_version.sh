#!/bin/bash

# 版本号更新脚本
# 用法: ./scripts/update_version.sh <版本号>
# 例如: ./scripts/update_version.sh 1.2.0

set -e

# 检查参数
if [ $# -eq 0 ]; then
    echo "❌ 错误: 请提供版本号"
    echo "用法: $0 <版本号>"
    echo "例如: $0 1.2.0"
    exit 1
fi

VERSION=$1

# 验证版本号格式 (语义化版本 x.y.z)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ 错误: 版本号格式不正确"
    echo "请使用语义化版本格式: x.y.z (例如: 1.2.0)"
    exit 1
fi

echo "🔍 准备更新版本号到: $VERSION"

# 检查是否在Git仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ 错误: 当前目录不是Git仓库"
    exit 1
fi

# 检查工作区是否干净
if ! git diff-index --quiet HEAD --; then
    echo "❌ 错误: 工作区有未提交的更改，请先提交或暂存"
    git status --short
    exit 1
fi

# 检查标签是否已存在
if git tag --list | grep -q "^v$VERSION$"; then
    echo "❌ 错误: 标签 v$VERSION 已存在"
    exit 1
fi

# 备份pubspec.yaml
cp pubspec.yaml pubspec.yaml.bak

echo "📝 更新pubspec.yaml..."

# 更新版本号
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^version: .*/version: $VERSION+1/" pubspec.yaml
else
    # Linux
    sed -i "s/^version: .*/version: $VERSION+1/" pubspec.yaml
fi

echo "✅ pubspec.yaml已更新:"
echo "旧版本: $(grep '^version:' pubspec.yaml.bak)"
echo "新版本: $(grep '^version:' pubspec.yaml)"

# 确认更改
echo ""
echo "📋 即将执行的操作:"
echo "1. 提交pubspec.yaml更改"
echo "2. 创建Git标签: v$VERSION"
echo "3. 推送到远程仓库"
echo ""

read -p "确认继续? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "❌ 操作已取消，恢复原始文件"
    mv pubspec.yaml.bak pubspec.yaml
    exit 1
fi

# 提交更改
echo "📦 提交更改..."
git add pubspec.yaml
git commit -m "chore: bump version to $VERSION"

# 创建标签
echo "🏷️  创建标签..."
git tag -a "v$VERSION" -m "Release version $VERSION"

# 推送到远程
echo "🚀 推送到远程仓库..."
git push origin main
git push origin "v$VERSION"

# 清理备份文件
rm pubspec.yaml.bak

echo ""
echo "🎉 版本号更新完成!"
echo "📋 摘要:"
echo "  - 版本号: $VERSION"
echo "  - 标签: v$VERSION"
echo "  - 提交已推送到远程仓库"
echo ""
echo "💡 现在GitHub Actions将自动开始构建和发布流程"
echo "   可以在这里查看进度: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git.*/\1/')/actions" 