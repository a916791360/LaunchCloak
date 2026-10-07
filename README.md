# LaunchCloak 🥷✨

[![Release](https://img.shields.io/github/v/release/a916791360/LaunchCloak?color=blue)](https://github.com/a916791360/LaunchCloak/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-lightgrey)](https://github.com/a916791360/LaunchCloak)
[![Language](https://img.shields.io/badge/language-Swift%206%20%2F%20SwiftUI-orange)](https://github.com/a916791360/LaunchCloak)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> **专为 macOS 设计的轻量级启动台图标隐藏与恢复状态栏工具**  
> 采用 Swift 6 + SwiftUI 构建，遵循 macOS 原生 **Soft（Liquid / SF）** 视觉质感。

---

## 📥 下载与安装 (Download & Install)

### 方式一：直接下载预编译版本（推荐）

1. 进入 [Releases 页面](https://github.com/a916791360/LaunchCloak/releases)；
2. 下载最新版本的 `LaunchCloak-v1.0.0-macos.zip`；
3. 解压后将 `LaunchCloak.app` 拖入 `/Applications`（应用程序）文件夹；
4. 双击打开，图标常驻于屏幕右上角菜单栏（`eye.slash` 图标）。

> 💡 **初次打开提示“已损坏”或“未知开发者”？**  
> 这是 macOS Gatekeeper 对未购买苹果商业开发者证书的开源 App 的安全拦截。只需在终端运行一次如下命令即可正常打开：  
> ```bash
> xattr -cr /Applications/LaunchCloak.app
> ```

---

## 💡 为什么需要 LaunchCloak？

在 macOS 26（以及以往版本）中，启动台与应用程序面板默认扫描全盘所有应用。许多作为后台插件、临时开发工具或隐私敏感的 App 无法在启动台中直接隐藏，造成启动台杂乱且缺乏隐私感。

**LaunchCloak** 通过轻巧的状态栏交互，利用 macOS 系统的底层特性，优雅实现了应用图标的**真·一键隐藏与无损还原**。

### 核心原理
- **安全隔离**：隐藏应用时，将其无损移入用户专属的安全隔离目录 `~/.hidden_apps.noindex/`。
- **Spotlight / 启动台忽略机制**：包含 `.noindex` 标识的目录会被系统索引机制彻底忽略，应用图标即刻从启动台与聚焦搜索中消失。
- **零数据风险**：应用的用户配置、偏好与数据（存放于 `~/Library/Application Support/`）完好无损，且恢复时按元数据精确原路退回。

---

## ✨ 核心特性

- 🪶 **状态栏轻驻 (LSUIElement)**：无 Dock 栏图标打扰，点击状态栏图标即开即用。
- 🫧 **Soft 原生质感**：基于 SwiftUI 的连续平滑圆角、系统毛玻璃透光材质与触感微动效。
- 🔍 **全宽分段 + 快速过滤**：“全部应用”与“已隐藏应用”水平等宽分段切换，支持中文拼音/英文实时搜索。
- 🛡️ **安全提示与权限处理**：受系统完整性保护的系统核心组件自动标注并禁用；需要管理员提权的操作自动调用原生授权。
- 📦 **一键全部还原**：在顶部“···”菜单中支持一键还原所有已隐藏应用，随时“一键重置”。

---

## 🛠️ 从源码构建

如需自行修改和编译：
```bash
# 克隆仓库
git clone https://github.com/a916791360/LaunchCloak.git
cd LaunchCloak

# 赋予执行权限并构建打包
chmod +x build.sh
./build.sh

# 编译并直接运行
./build.sh --run
```

---

## 📂 项目结构

```
LaunchCloak/
├── DESIGN.md           # Hallmark 交互规范与设计规范
├── README.md           # 项目开源说明与开发文档
├── LICENSE             # MIT 开源许可证
├── build.sh            # 自动化构建与代码签名脚本
└── src/
    ├── Models.swift     # 核心数据模型 (AppItem, HiddenAppRecord)
    ├── AppManager.swift # 目录扫描、隔离隐藏与原路恢复引擎
    ├── Views.swift      # SwiftUI Soft 质感界面 (状态栏浮窗、分段器、搜索与卡片)
    └── main.swift       # 应用程序主入口 (MenuBarExtra)
```

---

## 📄 许可证

MIT License © 2026 qingmeng. 欢迎开源社区提 Issue 与 PR！
