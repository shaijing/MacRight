# CLAUDE.md — MacRight 项目指南

## 项目概述

MacRight 是一个 macOS Finder 右键菜单扩展应用，功能：
- 在当前目录新建 txt / docx / xlsx / pptx 文件
- 在当前目录打开终端（Terminal / iTerm2 / Ghostty）
- 在当前目录打开 cmux（如果已安装）

## 技术栈

- **语言**: Swift 5.9+，最低部署目标 macOS 13.0 (Ventura)
- **宿主 App UI**: SwiftUI
- **扩展 UI**: AppKit (NSMenu)，使用 Finder Sync Extension (`FIFinderSync`)
- **构建方式**: `swiftc` 命令行编译 Universal Binary (arm64 + x86_64)
- **无第三方依赖**

## 项目结构

```
Sources/                  # Swift 源码
  ├── MacRight/            # 宿主 App（SwiftUI 设置界面）
  ├── FinderSyncExtension/ # Finder Sync 扩展源码
  │   ├── FinderSync.swift # 菜单构建 + 事件路由 + 动态卷监控
  │   └── Actions/         # 文件创建、终端和通知逻辑
  └── Shared/              # 两个 Target 共享代码
FinderSyncExtension/       # 扩展资源和模板
  └── Resources/Templates/ # blank.docx/xlsx/pptx 空白模板
Scripts/                   # 构建和模板生成脚本
build.sh                   # swiftc 一键构建/签名/安装脚本（支持版本号参数）
build-xcode.sh             # Xcode/xcodebuild 一键构建/签名/安装脚本（可选）
project.yml                # 唯一构建配置，生成 .xcodeproj / Info.plist / entitlements
```

## 构建命令

```bash
# 安装构建前置依赖
brew install xcodegen

# 一键构建、签名、安装到 /Applications 并启动
./build.sh

# 清理构建产物和缓存
./clean.sh

# CI 构建（仅构建签名，不安装）
CI=true ./build.sh v1.0.0

# 可选：使用完整 Xcode / xcodebuild 构建
./build-xcode.sh
CI=true ./build-xcode.sh v1.0.0

# 生成 Office 空白模板（首次或模板丢失时）
python3 Scripts/create_templates.py

# 生成 Xcode 项目、Info.plist 和 entitlements
xcodegen generate
```

## 发布流程

推送 `v*` 标签触发 GitHub Actions 自动构建 Universal Binary 并发布：
```bash
git tag v1.0.0 && git push origin v1.0.0
```

## 调试

```bash
# 查看扩展日志
log stream --predicate 'eventMessage CONTAINS "MacRight"'

# 检查扩展注册状态
pluginkit -m -p com.apple.FinderSync

# 强制重新注册
killall pkd && sleep 1 && pluginkit -e use -i com.macright.app.FinderSyncExtension
```

## 关键约束（踩坑记录）

1. **NSMenuItem 不要设置 target** — Finder Sync Extension 的菜单项必须依赖 responder chain 路由，设置 `item.target = self` 会导致点击无响应
2. **不要使用子菜单** — macOS Sequoia 上 Finder Sync 扩展的子菜单行为异常（父菜单提前消失），这是系统级限制
3. **扩展必须启用 App Sandbox** — `com.apple.security.app-sandbox = true`，否则 pluginkit 拒绝注册
4. **扩展入口点** — 编译扩展时必须指定 `-Xlinker -e -Xlinker _NSExtensionMain`，扩展没有自己的 main()
5. **避免 build/ 目录残留 .appex** — 会导致菜单项重复，build.sh 已处理
6. **onChange API** — 使用 macOS 13 兼容的 `onChange(of:) { newValue in }` 而非 macOS 14+ 的 `onChange(of:initial:_:)`
7. **文件写入权限** — 沙盒限制下，~/Desktop、~/Documents 等用户目录可写，/Users 等系统目录不可写，属正常行为

## 动态卷监控

FinderSync 监听 NSWorkspace 卷挂载/卸载通知，动态更新 `FIFinderSyncController.default().directoryURLs`，支持外接硬盘、U 盘等移动存储设备。同时使用 30 秒定时器作为 fallback。

## 标识符

- Host App Bundle ID: `com.macright.app`
- Extension Bundle ID: `com.macright.app.FinderSyncExtension`
- App Group: `group.com.macright.app`

## 宿主 App ↔ 扩展通信

通过 App Group 共享 `UserDefaults(suiteName: "group.com.macright.app")` 传递偏好设置（终端选择、文件类型开关、默认文件名）。

## 代码规范

- 所有用户可见文本使用中文
- NSLog 前缀统一为 `"MacRight: "`
- 文件创建使用独占文件描述符，避免重名竞争
