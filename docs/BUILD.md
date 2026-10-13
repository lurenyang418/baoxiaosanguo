# 构建与运行指南

本项目使用 Godot 4.7.2。打开 `project.godot` 后可在编辑器按 F5 运行，也可在仓库根目录使用 `godot --path .`。

主要目标平台为 Apple Silicon macOS、Windows x64、Android ARM64 和 iPhone/iPad。macOS 导出同时包含 Intel 架构；Windows ARM64 是额外预设。项目尚未配置 Linux 和 Web 导出。

## 首次打开

安装与项目版本匹配的 Godot 导出模板。在新环境中先导入资源：

```sh
godot --headless --editor --import --path .
```

编辑器首次打开项目时也会导入资源。

## 平台依赖

| 平台 | 依赖 | 检查方式 |
|---|---|---|
| 全部 | Godot 4.7.x 和对应导出模板 | `godot --version` |
| macOS | Xcode Command Line Tools；公开分发签名和公证需 Developer ID | `xcode-select -p` |
| Android | JDK 17、Android SDK、Gradle 导出组件 | `java -version`、`ls ~/Library/Android/sdk` |
| iOS | macOS、完整 Xcode 和 iOS 平台组件 | `xcodebuild -version` |
| Windows | 可用的 Windows 环境用于实际运行验收；可在本项目支持的构建环境导出 | 目标设备验收 |

Android 导出使用 Gradle。在 Godot「编辑器设置 → 导出 → Android」中配置 Java SDK Path 和 Android SDK Path。Godot 4.7 推荐 JDK 17、Platform 35 和 Build-Tools 35.0.1；当前预设仍使用 Android API 34，正式发布前需重新确认目标 SDK。Android SDK 组件列表以 [Godot Android 导出文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)为准。

macOS 可使用以下命令安装常见 Android SDK 组件：

```sh
brew install --cask android-commandlinetools
sdkmanager --sdk_root="$HOME/Library/Android/sdk" "platform-tools" "build-tools;35.0.1" "platforms;android-35" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709"
```

非默认 SDK 路径可通过 `ANDROID_SDK_ROOT` 指定。如果检测到 Java 27，Android 构建脚本会尝试查找本机 JDK 17 或 `JDK17_HOME`。

## 构建命令

在项目根目录执行：

```sh
./scripts/build_macos.sh             # macOS Debug .app
./scripts/build_macos.sh --release   # macOS ad-hoc 签名 DMG（内含“应用程序”快捷方式）
./scripts/build_macos.sh --release --arm64  # Apple Silicon 单架构 DMG
./scripts/build_macos.sh --release --x86_64 # Intel 单架构 DMG
./scripts/build_windows.sh           # Windows x64 Debug .exe
./scripts/build_windows.sh --arm64   # Windows ARM64 Debug .exe
./scripts/build_windows.sh --release # Windows x64 Release .exe
./scripts/build_android.sh           # Android Debug .apk
./scripts/build_android.sh --release # Android Release .apk（本机安装/侧载）
./scripts/build_ios.sh               # iPhone/iPad Xcode 工程（尚未签名）
```

## GitHub Actions 自动构建

`.github/workflows/build.yml` 仅在推送 `v*` 格式的 tag 时运行，例如 `v0.1.0`。它会导出 macOS Apple Silicon/Intel DMG、Windows x64、Android ARM64 APK，以及未签名的 iOS Xcode 工程。成功后可在该次 Actions 运行的 Artifacts 中下载；构建产物保留 14 天。iOS 工程以 ZIP 上传，需在 Xcode 中配置签名后才能安装到设备。

工作流使用 GitHub 托管的 macOS runner 执行现有构建脚本，因此 Windows 产物是交叉导出的 `.exe`，工作流不会代替 Windows 设备上的实际运行验收。Android 侧载包由 CI 临时生成的调试密钥签名，适用于验证安装；不同运行产生的 APK 不保证可覆盖安装。工作流不发布 GitHub Release，也不使用个人签名密钥。

### Android Release 签名

Release 使用优化构建并导出 APK，面向本机安装和侧载分发，不生成 Google Play 用的 AAB。签名策略参考仓库旁的 `../../xpod`：如果配置了本机稳定密钥就使用它；否则自动使用 `$HOME/.android/debug.keystore`。首次构建时若该文件不存在，脚本会生成 Android 标准调试密钥并用于 Release 签名。该调试密钥适合非商店分发；请保留并备份它，之后更新安装包必须继续使用同一密钥。不要把密钥提交到 Git。

如需使用自己的稳定密钥，在项目根目录创建被 Git 忽略的 `.android-release.env`：

```sh
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/.android/baoxiaosanguo.keystore"
GODOT_ANDROID_KEYSTORE_RELEASE_USER="你的密钥别名"
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="你的密钥密码"
```

将该文件权限限制为当前用户可读写（`chmod 600 .android-release.env`），再运行 `./scripts/build_android.sh --release`。脚本也接受同名环境变量；环境变量已设置时会覆盖此文件中的值。三项配置必须同时提供，且密钥文件必须存在。Godot 支持通过这些环境变量设置 Android 导出签名信息，见 [Godot Android 导出文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)。

构建结果默认写入 Git 忽略的仓库根目录 `build/`。构建脚本会在输出目录创建 `.gdignore`，避免 Godot 把旧产物和诊断截图重新导入游戏。Android APK 放在 `build/android/` 子目录；设置 `BAOXIAO_BUILD_DIR` 后也会在指定目录下建立 `android/`。例如：

```sh
BAOXIAO_BUILD_DIR="$PWD/build/platform-expansion-milestone" ./scripts/build_macos.sh
BAOXIAO_BUILD_DIR="$PWD/build/platform-expansion-milestone" ./scripts/build_android.sh
BAOXIAO_BUILD_DIR="$PWD/build/platform-expansion-milestone" ./scripts/build_windows.sh
```

| 命令 | 主要产物 | 导出模式 |
|---|---|---|
| `build_macos.sh` | `BaoXiaoSanGuo.app` | Debug |
| `build_macos.sh --release` | `BaoXiaoSanGuo.dmg` | Release，ad-hoc 签名，内含 `/Applications` 快捷方式 |
| `build_macos.sh --release --arm64` | `BaoXiaoSanGuo-arm64.dmg` | Release，Apple Silicon |
| `build_macos.sh --release --x86_64` | `BaoXiaoSanGuo-x86_64.dmg` | Release，Intel |
| `build_windows.sh` | `BaoXiaoSanGuo-windows-x64.exe` | Debug；加 `--release` 导出优化版本 |
| `build_windows.sh --arm64` | `BaoXiaoSanGuo-windows-arm64.exe` | Debug |
| `build_android.sh` | `android/baoxiaosanguo-debug.apk` | Debug |
| `build_android.sh --release` | `android/baoxiaosanguo-release.apk` | Release，本机签名侧载 |
| `build_ios.sh` | `ios-xcode/BaoXiaoSanGuo.xcodeproj` | 仅导出工程 |

iOS 脚本会生成 Xcode 工程、PCK、图标和原生库；为避免覆盖已有成果，它不会覆盖已存在的 `ios-xcode/` 目录。需要再次导出时，请指定新的 `BAOXIAO_BUILD_DIR`。在 Xcode 中选择 App target，将 `TEAMIDHERE` 替换成自己的 Apple Team ID，再构建或归档。Bundle ID 为 `tech.lury.baoxiaosanguo`。该步骤只生成 Xcode 工程，不会生成已签名 IPA。当前目标为 iOS 16.0 及以上版本的 iPhone/iPad，使用横屏方向。详情见 [Godot iOS 导出文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html)。

macOS Release 脚本先导出 `.app`，再制作 DMG，并在映像中添加指向 `/Applications` 的快捷方式。DMG 使用 Godot 内置 ad-hoc 签名并关闭公证，无需 Apple ID 或签名证书，适合本机测试。macOS 可能仍会对下载的包显示安全提示；公开分发需改用 Developer ID 签名并公证。机密导出设置应保存在 `export_presets.cfg` 之外，详见[导出项目文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)。

当前 Godot 4.7.2 安装的 macOS Release 模板只带 Universal 2 可执行文件，直接将预设架构改为 `arm64` 或 `x86_64` 会因模板缺少对应的单架构二进制而失败。脚本的两个架构选项会先导出 Universal 2，再用 macOS 自带的 `lipo` 提取所需架构，并重新 ad-hoc 签名；不需要自行编译 Godot 模板。Android Release 预设目前只包含 `arm64-v8a`，因此当前 Android APK 是单独的 ARM64 产物。

## 图标、画面与输入

游戏以 256×240 逻辑分辨率绘制。桌面窗口默认 768×720，使用整数倍视口缩放保持像素边缘清晰；默认关闭字体抗锯齿。启动时隐藏 Godot 引擎画面，先播放原创俏皮开场，再进入标题。Android 在 Godot 启动前显示系统启动图标。

macOS 使用 `assets/branding/app_icon_macos.png`；Windows、iOS 和 Android 使用 `assets/branding/app_icon.png`。Android 自适应图标由 `adaptive_foreground.png`、`adaptive_background.png` 和 `adaptive_monochrome.png` 组成。标题画面使用宽版 `logo.png`。

Android 横屏运行，游戏画面居中，左右留出触控区域：左侧方向键，右侧 A/B 和菜单按钮。点按地图可定位光标，竖向滑动地图可滚屏，长按方向键可连续移动。

Debug 构建包含从原版 NSF 渲染的 MP3 音乐和音效。NSF 位于项目外的 `../BaoXiaoSanGuo/#音乐/`。工具 `research/tools/render/render_nsf.py` 使用 `game-music-emu` 和 `ffmpeg` 渲染 31 首曲目；事件到曲目的对应关系仍属暂定，较长曲目目前在 42 秒处截取并循环。

## Android 安装启动

连接 Android 设备并启用调试后：

```sh
adb install -r build/android/baoxiaosanguo-debug.apk
adb shell monkey -p tech.lury.baoxiaosanguo 1
```

## 回归检查

在项目根目录运行：

```sh
./scripts/run_campaign_regression.sh
BAOXIAO_PLAY_GUI=1 BAOXIAO_CAPTURE_STAGE_IMAGES=1 BAOXIAO_PLAY_SPEED=8 ./scripts/run_campaign_playthrough.sh
./scripts/run_audio_smoke.sh
```

回归脚本使用隔离存档。图形化流程会运行全部 19 关并截取开场和结尾画面；`BAOXIAO_PLAY_SPEED=8` 会缩短动画以便回归。音频检查会采样 Godot Master 总线并报告音乐和音效是否有信号，但不会判断扬声器输出或主观听感。无头音频模式 `BAOXIAO_AUDIO_HEADLESS=1` 使用 Dummy 音频驱动；检查 macOS CoreAudio 时应使用普通图形模式。

## 正式发布前

当前 Bundle ID 和 Android 包名统一为 `tech.lury.baoxiaosanguo`。公司名和版权元数据暂时留空，确定发行方和权利声明后再填写。检查图标、版本号和 Android 目标 SDK。公开分发 macOS 包时需配置 Developer ID 和公证凭据。Android 当前面向侧载分发，默认使用本机 Android Debug 密钥；若需要跨机器保持更新兼容性，配置并备份一份稳定密钥。密码和私钥不得提交到 Git。

## 常见问题

- **缺少导出模板：** 在 Godot 编辑器安装与当前 Godot 版本匹配的模板。
- **Android Gradle 或 Java 失败：** 使用 JDK 17，并检查编辑器设置中的 Java 和 Android SDK 路径。
- **`INSTALL_FAILED_UPDATE_INCOMPATIBLE`：** 设备上同包名应用由不同签名密钥安装；卸载旧应用后再装 Debug APK。
- **macOS 阻止下载的 App：** 当前 Release DMG 使用 ad-hoc 签名并未公证，适合本机测试。公开分发时配置 Developer ID 签名和公证，见 [Godot macOS 导出文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html)。
- **新构建仍显示 Godot 默认图标：** 在编辑器重新导入资源后再次导出。`build/` 中已有的包不会随图标源文件或导出预设变化而自动更新。

ROM 逆向资料从[研究日志](../research/ROM_RESEARCH.md)和[研究索引](RESEARCH.md)开始阅读；历史阶段记录位于[阶段记录目录](milestones/README.md)。测试计划、已整理的验收结论和未完成项见[测试记录](testing/README.md)。
