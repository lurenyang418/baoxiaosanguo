# 平台扩展阶段记录｜2026-10-06

## 功能变化

原版结局画面右下角的 **B 跳过** 现在可触控；点按其他区域会进入制作人员名单或下一页。新增 Windows x64 和 ARM64 导出预设，Godot pack 嵌入各自可执行文件，并沿用现有应用图标。

## 构建产物

本版本的产物位于 `build/platform-expansion-milestone/`：

| 平台 | 文件 | 检查状态 |
|---|---|---|
| macOS Intel + Apple Silicon | `BaoXiaoSanGuo.app` | 已导出；内置可执行文件通过无头启动 |
| Android ARM64 | `baoxiaosanguo-debug.apk` | 已导出；APK 签名校验通过 |
| Windows x64 | `BaoXiaoSanGuo-windows-x64.exe` | 已导出；PE 架构已检查 |
| Windows ARM64 | `BaoXiaoSanGuo-windows-arm64.exe` | 已导出；PE 架构已检查 |

Windows 包是未签名 Debug 构建。这台 Mac 当时没有 Windows 运行环境或 Android 设备，因此未在目标设备上试玩。Linux、Web 和 iOS 导出预设仍未准备；本机 Godot 4.7.2 模板含 Windows x64/ARM64，不含 Linux/Web。

独立 Godot 场景检查确认：触控结局主画面可继续播放，点右下角可打开通关记录。没有删除已有构建或用户存档。

APK 的 Android APK Signature Scheme v2 校验通过。macOS 二进制含 `x86_64` 和 `arm64`，无头模式状态码为 0。受限环境下启动时出现 Godot 日志文件与系统证书警告。`file` 将 Windows 文件识别为 x86-64 与 Aarch64 的 PE32+ GUI 可执行文件。SHA-256：

| 包 | SHA-256 |
|---|---|
| Android APK | `b7cbd4ac733bb83ee74bc0ded45dd58690030588fc9121a79f68dadbfb65b5e1` |
| Windows x64 EXE | `819145b0a958ac839b639628263f0d58ad6425e77d8cde7598596021757348ab` |
| Windows ARM64 EXE | `05b142bddaa4c914a8d850febd63cff47b8ce7ea056ece04876a07e12d1e8b66` |

## FCEUX 进程清理

发现并关闭了前一轮 ROM 截取留下的 5 个暂停状态 FCEUX CLI 进程。另一次短暂录音尝试未生成 WAV，因此原版结局曲目仍未映射。本次启动的 CLI 与 GUI 也已关闭；最终进程检查没有发现 FCEUX。
