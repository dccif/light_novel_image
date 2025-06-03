@echo off
setlocal EnableDelayedExpansion

REM 版本号更新脚本 (Windows版本)
REM 用法: scripts\update_version.bat <版本号>
REM 例如: scripts\update_version.bat 1.2.0

echo.
echo 🔍 轻小说图片浏览器 - 版本号更新工具
echo =====================================

REM 检查参数
if "%1"=="" (
    echo ❌ 错误: 请提供版本号
    echo 用法: %0 ^<版本号^>
    echo 例如: %0 1.2.0
    exit /b 1
)

set VERSION=%1

REM 简单验证版本号格式
echo %VERSION% | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo ❌ 错误: 版本号格式不正确
    echo 请使用语义化版本格式: x.y.z (例如: 1.2.0)
    exit /b 1
)

echo 🔍 准备更新版本号到: %VERSION%

REM 检查是否在Git仓库中
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误: 当前目录不是Git仓库
    exit /b 1
)

REM 检查工作区是否干净
git diff-index --quiet HEAD -- >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误: 工作区有未提交的更改，请先提交或暂存
    git status --short
    exit /b 1
)

REM 检查标签是否已存在
git tag --list | findstr /x "v%VERSION%" >nul
if not errorlevel 1 (
    echo ❌ 错误: 标签 v%VERSION% 已存在
    exit /b 1
)

REM 备份pubspec.yaml
copy pubspec.yaml pubspec.yaml.bak >nul

echo 📝 更新pubspec.yaml...

REM 更新版本号
powershell -Command "(Get-Content pubspec.yaml) -replace '^version: .*', 'version: %VERSION%+1' | Set-Content pubspec.yaml"

echo ✅ pubspec.yaml已更新
type pubspec.yaml | findstr "^version:"

echo.
echo 📋 即将执行的操作:
echo 1. 提交pubspec.yaml更改
echo 2. 创建Git标签: v%VERSION%
echo 3. 推送到远程仓库
echo.

set /p confirm=确认继续? (y/N): 
if /i not "%confirm%"=="y" (
    echo ❌ 操作已取消，恢复原始文件
    move pubspec.yaml.bak pubspec.yaml >nul
    exit /b 1
)

REM 提交更改
echo 📦 提交更改...
git add pubspec.yaml
git commit -m "chore: bump version to %VERSION%"

REM 创建标签
echo 🏷️ 创建标签...
git tag -a "v%VERSION%" -m "Release version %VERSION%"

REM 推送到远程
echo 🚀 推送到远程仓库...
git push origin main
git push origin "v%VERSION%"

REM 清理备份文件
del pubspec.yaml.bak

echo.
echo 🎉 版本号更新完成!
echo 📋 摘要:
echo   - 版本号: %VERSION%
echo   - 标签: v%VERSION%
echo   - 提交已推送到远程仓库
echo.
echo 💡 现在GitHub Actions将自动开始构建和发布流程

for /f "tokens=2 delims=/" %%a in ('git config --get remote.origin.url') do (
    echo    可以在这里查看进度: https://github.com/%%a/actions
)

pause 