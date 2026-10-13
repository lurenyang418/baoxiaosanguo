# 范围攻击阶段记录｜2026-10-05

## 构建产物

产物位于 `build/area-attack-milestone-final/`。保留了旧构建和用户文件，macOS 与 Android 包使用相同的游戏源码。

| 产物 | 配置 |
|---|---|
| `BaoXiaoSanGuo.app` | macOS Debug Universal 2，arm64 + x86_64，无需 Rosetta |
| `baoxiaosanguo-debug.apk` | Android Debug ARM64，88,884,945 字节 |
| `checksums.json` | APK、macOS 可执行文件与 PCK 的 SHA-256 和大小 |
| `area-attack-preview.png` | 移动端攻击切换按钮的场景预览 |

APK SHA-256：`ba127d85a343cf69b257d4d6da589af8cb08bb9a953014af13430dd98a7bbd43`。Android Build Tools 36.0.0 的 APK Signature Scheme v2 校验通过。这些是本地 Debug 包，没有公开发布或上传。

从项目根目录重建：

```sh
BAOXIAO_BUILD_DIR="$PWD/build/area-attack-milestone-final" ./scripts/build_macos.sh
BAOXIAO_BUILD_DIR="$PWD/build/area-attack-milestone-final" ./scripts/build_android.sh
```

## 功能检查

临时可运行场景检查通过：十字形和方形范围伤害、阵营筛选、HP 上限、HP 降至 0 后移除单位、重叠中心部署过滤、第七关 62 号单位通过键盘和触控切换技术、五目标伤害、一次行动只结算一个面板、取消、存档与新场景恢复、最后单位行动后的回合切换，以及范围击杀后进入下一关。群体治疗回归检查也通过。已目视检查移动端攻击切换按钮的场景截图。原版受控轨迹见[研究索引](../RESEARCH.md)和[研究日志](../../research/ROM_RESEARCH.md)。

## 导出与设备检查

macOS 导出成功；默认入口无头运行 120 帧后以状态码 0 退出。强制关闭仍有 ObjectDB/resource-in-use 警告，因此没有验证长时间运行后的正常退出。Android 导出成功，但退出编辑器时仍有 scan-thread-aborted 警告。

使用 `adb install -r` 将 APK 安装到小米 22021211RC（munch，API 33），启动别名 `com.godot.game.GodotAppLauncher` 正常运行。检查了横屏标题画面；启动日志中没有 SCRIPT ERROR、Parse Error、FATAL EXCEPTION 或 ERROR: match。已有存档哈希保持为 `2551eb37ba026d18b12ca0323971e83bd50d590b93be9274264069dc833c4859`，没有写入存档。该设备的第一关存档没有范围技术单位，因此新增范围攻击只在可运行场景中检查，未在真机战斗里施放。此前的 Android 基础战斗、触控和回合检查见 `BUILD_HEALING_MILESTONE.md`。

原版玩家技术菜单与消耗、特殊零数值效果、完整敌方变体选择和技术动画仍未完成；演示版攻击选择器仍是临时界面。
