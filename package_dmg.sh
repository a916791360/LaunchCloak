#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APP_NAME="LaunchCloak"
VERSION="1.1.1"
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

# 3. 写入一键修复脚本
echo "==> 🛠️ 生成【遇到已损坏点我一键修复.command】..."
cat << 'SCRIPT' > "$STAGING_DIR/遇到已损坏点我一键修复.command"
#!/bin/bash
clear
echo "=========================================================="
echo "         LaunchCloak macOS 运行权限一键修复助手"
echo "=========================================================="
echo ""
echo "💡 说明：本程序为独立正版开发，未向苹果官方缴纳 688元/年"
echo "   商业开发者证书年费。macOS 默认会对非 App Store 软件启动"
echo "   安全隔离保护，导致提示“文件已损坏”或“无法打开”。"
echo ""

APP_PATH="/Applications/LaunchCloak.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 提示：未在【应用程序 (Applications)】文件夹中找到 LaunchCloak.app！"
    echo ""
    echo "👉 正确操作步骤："
    echo "   1. 请先将本安装包中的【LaunchCloak】拖入【Applications】文件夹；"
    echo "   2. 拖入完成后，再双击运行本修复脚本。"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

echo "🚀 正在为您解除 macOS Gatekeeper 隔离保护..."
xattr -cr "$APP_PATH" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 修复成功！已彻底解除系统隔离保护限制。"
    echo "🎉 您现在可以在【启动台】或【应用程序】中直接双击打开 LaunchCloak 了！"
    echo "📌 提示：软件打开后常驻于屏幕右上角顶部菜单栏（闭眼图标）。"
else
    echo "⚠️ 正在尝试管理员提权修复，若弹出密码提示请输入 Mac 锁屏密码（输入时不显示星号）："
    sudo xattr -cr "$APP_PATH"
    echo ""
    echo "✅ 修复完成！请直接双击打开 LaunchCloak。"
fi

echo ""
read -p "按回车键退出..."
exit 0
SCRIPT

chmod +x "$STAGING_DIR/遇到已损坏点我一键修复.command"

# 4. 写入新手安装必看说明
echo "==> 📝 生成【新手安装必看说明.txt】..."
cat << 'DOC' > "$STAGING_DIR/新手安装必看说明.txt"
==========================================================
              LaunchCloak 安装与使用指南
==========================================================

一、安装步骤（仅需 5 秒）：
1. 将【LaunchCloak】图标拖入【Applications】（应用程序）文件夹中；
2. 拖入完成后，进入“启动台”或“应用程序”文件夹，双击打开【LaunchCloak】；
3. 打开后，软件自动常驻在屏幕【右上角顶部菜单栏】（图标为闭眼符号 👁️ ），点击即可展开使用！

二、常见问题与解决办法：
❓ 问：双击打开时提示“文件已损坏，请移到废纸篓”或“无法验证开发者”怎么办？
👉 答：这是 macOS 系统（尤其是 macOS 15/26）对未购买苹果 688元/年企业商业证书的独立软件的常规安全拦截（绝非软件损坏）。
   只需双击本镜像中的【遇到已损坏点我一键修复.command】，等待终端提示“修复成功”，即可永久正常打开！

三、核心功能说明：
- 隐藏与恢复：点击应用卡片右侧按钮即可秒级隐藏/恢复启动台图标；
- 隐私锁屏密码：点击右上角 ··· -> 偏好设置，开启“访问已隐藏标签需密码验证”，进入已隐藏列表自动唤起 Touch ID / 锁屏密码；
- 开机自启：偏好设置内可一键开启开机自启动。
DOC

# 5. 生成 DMG
echo "==> 💿 正在打包生成 DMG 镜像: $DMG_NAME..."
rm -f "$DIR/$DMG_NAME"
hdiutil create -volname "LaunchCloak Installer" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DIR/$DMG_NAME"

rm -rf "$STAGING_DIR"
echo "==> ✅ DMG 打包成功！位于: $DIR/$DMG_NAME"
