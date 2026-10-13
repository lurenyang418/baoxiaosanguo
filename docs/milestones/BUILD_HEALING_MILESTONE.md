# 治疗功能阶段记录｜2026-10-05

## 构建产物

新构建位于 `build/healing-milestone/`，保留了上级 `build/` 中的旧产物和用户文件。

| 产物 | 配置 | 大小 |
|---|---|---|
| `BaoXiaoSanGuo.app` | macOS Debug Universal 2（arm64 + x86_64） | 约 188.5 MiB |
| `baoxiaosanguo-debug.apk` | Android Debug ARM64 | 88,882,921 字节 |

`build/healing-milestone/checksums.json` 记录 APK、macOS 可执行文件和 PCK 的 SHA-256。APK 哈希为 `bba36be3f2d7b5c89133744a7721af663a9fe44ac6847ddbecb965eb628533dc`。Android Build Tools 36.0.0 的 APK v2 签名校验通过。这是本地 Debug 包，不是公开发布签名包，没有发布或上传。

Android manifest：包名 `com.example.baoxiaosanguo`，版本名 `0.1.0`，版本号 1，min SDK 24、target SDK 34、compile SDK 36。启动别名为 `com.godot.game.GodotAppLauncher`。

## 重建

需要 Godot 4.7.2、对应导出模板及本机 SDK。在项目根目录运行：

```sh
BAOXIAO_BUILD_DIR="$PWD/build/healing-milestone" ./scripts/build_macos.sh
BAOXIAO_BUILD_DIR="$PWD/build/healing-milestone" ./scripts/build_android.sh
```

两个导出均成功。Android 导出在编辑器关闭时记录了 scan-thread-aborted 警告，但签名校验和安装均成功。macOS App 通过默认主场景启动；导出模板不支持命令行指定场景路径，尝试覆盖场景被引擎拒绝。随后默认场景无头运行 `--quit-after 120`，状态码为 0。强制退出仍有 ObjectDB/resource-in-use 警告，因此不能据此声称正常清理已验证。治疗预览和场景功能检查在导出前另行完成。

## Android 真机检查

设备为小米 22021211RC（`munch`），Android API 33、Adreno 650。通过 `adb install -r` 安装，没有清除应用数据。实际触屏检查包括：

- 启动应用、横屏标题、开始菜单、难度选择和开场画面。
- 第一关地图、侧边触控按钮和单位命令菜单。
- “全军休息”可将回合从 1 推进到 2、3，菜单仍可正常操作。
- 读取既有的第 0 关第 17 回合存档后，单位和地图位置恢复。
- 操作前后进度文件 SHA-256 相同。
- 检查期间进程日志没有脚本解析/加载错误或致命异常。设备唤醒后画面正常渲染；最初黑屏时应用处于暂停状态。

旧存档没有治疗单位，因此未在这台 Android 设备上实际进行治疗战斗。未检查音频听感、全部 19 关或长时间运行。原版范围攻击证据及场景治疗、存档和回合检查见[研究日志](../../research/ROM_RESEARCH.md)。

