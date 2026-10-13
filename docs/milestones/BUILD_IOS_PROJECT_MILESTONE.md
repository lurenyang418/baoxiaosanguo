# iOS Xcode 工程阶段记录｜2026-10-06

目标平台为 Apple Silicon macOS、Windows x64、Android ARM64 和 iPhone/iPad。前三个平台的 Debug 包位于 `build/platform-expansion-milestone/`；iOS 工程位于 `build/ios-xcode/`。

## iOS 导出

`./scripts/build_ios.sh` 可导出新的 Xcode 工程和游戏资源包。脚本会检查 Godot、导出模板、macOS 和 Xcode；若 `ios-xcode/` 已存在，会拒绝覆盖，以保留之前的导出。再次导出时请为 `BAOXIAO_BUILD_DIR` 指定新的绝对路径。

Godot 导出成功。Xcode 工程包含 `arm64` iOS 库、9.2 MB 游戏资源包、由当前 App 图标生成的图标变体、iPhone/iPad target（`TARGETED_DEVICE_FAMILY = "1,2"`）以及横屏方向。完整导出目录约 439 MB。

预设中的 `TEAMIDHERE` 和 Bundle ID `com.example.baoxiaosanguo` 都是占位值，签名构建前需在 Xcode 中换成实际值。这台 Mac 未安装有效的代码签名身份。系统有 Xcode 16.4，但缺少 iOS 18.5 平台组件；无签名的 `xcodebuild` 因找不到 iOS destination 而失败。因此本阶段只完成 Xcode 工程导出，没有生成可运行的 iPhone 包或已签名 IPA。

Godot 导出 iOS 需 Apple Team ID 和 Bundle ID；设备构建需使用生成的 Xcode 工程。详见 [Godot 4.7 iOS 导出指南](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html)。没有删除旧构建、源文件或存档。
