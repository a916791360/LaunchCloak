#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APP_NAME="LaunchCloak"
VERSION="1.1.3"
DMG_NAME="${APP_NAME}-v${VERSION}-Installer.dmg"
STAGING_DIR="/tmp/LaunchCloak_DMG_Staging"

echo "==> 🚀 开始准备 DMG 打包环境..."

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 1. 复制 LaunchCloak.app
echo "==> 📦 复制 $APP_NAME.app..."
cp -R "$DIR/$APP_NAME.app" "$STAGING_DIR/"

# 2. 创建 Applications 软链接
echo "==> 🔗 创建 Applications 替身快捷方式..."
ln -s /Applications "$STAGING_DIR/Applications"

# 3. 写入新手安装必看说明
echo "==> 📝 生成【新手安装必看说明.txt】..."
cat << 'DOC' > "$STAGING_DIR/新手安装必看说明.txt"
==========================================================
              LaunchCloak 安装与打开指南
==========================================================

一、极简安装步骤（仅需 5 秒）：
1. 将左侧【LaunchCloak】图标拖入右侧【Applications】（应用程序）文件夹；
2. 拖入完成后，在“启动台”或“访达 > 应用程序”中，双击打开【LaunchCloak】；
3. 打开后，软件自动常驻在屏幕【右上角顶部菜单栏】（图标为闭眼符号 👁️ ），点击即可展开使用！

二、⚠️ 首次打开若提示“无法验证开发者”或“已损坏”？
这是 macOS 系统（尤其是 macOS 15 Sequoia / 14 Sonoma）对未购买苹果 688元/年商业年费证书的独立开源软件的常规安全保护拦截（绝非软件损坏）。

👉 官方 1 步快速解决办法（仅需设置一次，永久生效）：
1. 打开 Mac【系统设置】；
2. 点击左侧【隐私与安全性】，在右侧界面往下滑动；
3. 找到提示：“已阻止使用 LaunchCloak，因为无法验证其开发者”；
4. 点击旁边的【仍要打开】按钮，输入 Mac 锁屏密码确认即可！

💡 终端极客快捷方式（可选）：
打开终端运行此行命令亦可直接解除拦截：
sudo xattr -cr /Applications/LaunchCloak.app

三、核心功能说明：
- 访达与启动台隐身：点击隐藏后，应用在【访达】和【启动台】彻底隐身，不留痕迹；
- 隐私锁屏密码：偏好设置内开启“访问已隐藏标签需密码验证”，进入已隐藏列表自动唤起 Touch ID / 锁屏密码；
- 开机自启：偏好设置内可一键开启开机自启动。
DOC

# 5. 生成 DMG
echo "==> 💿 正在打包生成 DMG 镜像: $DMG_NAME..."
rm -f "$DIR/$DMG_NAME"
hdiutil create -volname "LaunchCloak Installer" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DIR/$DMG_NAME"

rm -rf "$STAGING_DIR"
echo "==> ✅ DMG 打包成功！位于: $DIR/$DMG_NAME"
