# 技术子菜单阶段记录｜2026-10-05

## 可运行构建包

产物位于 `build/technique-menu-milestone/`。旧构建和用户文件均保留，没有删除文件。macOS 和 Android 使用相同的最终游戏源码与现有 Debug 预设；未公开发布或上传。

| 产物 | 配置 |
|---|---|
| `BaoXiaoSanGuo.app` | macOS Debug Universal 2，arm64 + x86_64 |
| `baoxiaosanguo-debug.apk` | Android Debug ARM64，88,901,657 字节 |
| `checksums.json` | APK、macOS 可执行文件和 PCK 的 SHA-256 与大小 |
| `technique_menu-preview.png` | 源场景技术菜单预览 |
| `technique_targets-preview.png` | 源场景技术/目标控制预览 |
| `android-target-button.png` | Android 真机目标按钮截图 |

APK SHA-256：`0ef3195db4aa1e874421c75b2a5ced35bb5bdca99caa028d51b75b95e13e8087`。Android Build Tools 36.0.0 的 APK Signature Scheme v2 校验通过。包名 `com.example.baoxiaosanguo`、版本 0.1.0/代码 1、min SDK 24、target SDK 34 未变；没有添加签名凭据。仓库没有单独的公开发布策略，本阶段使用已有 Debug 配置。

从项目根目录重建：

```sh
BAOXIAO_BUILD_DIR="$PWD/build/technique-menu-milestone" ./scripts/build_macos.sh
BAOXIAO_BUILD_DIR="$PWD/build/technique-menu-milestone" ./scripts/build_android.sh
```

## 已完成的游戏功能检查

临时可运行源码场景检查通过：

- 子菜单项目数与静态解码的 ROM 分支相符。
- 必须先选择治疗或攻击技术，再选目标；错误阵营会被拒绝，不可用的状态变体不会消耗行动。
- 第七关默认 type62 可选自身治疗、单体攻击和十字攻击；触控行选择与键盘导航有效。
- C/V 正向/反向切换目标、侧边目标按钮调用、保留有效目标、无目标提示和取消流程均有效。
- 十字/方形伤害和重叠中心过滤保持既有行为。
- 调整探针以适配新子菜单后，五目标伤害、HP 为 0 后退场、一次行动结算、存档/新场景恢复、最后单位行动后切换敌方回合，以及胜利后进入下一关检查通过。
- type65 的五目标治疗、HP 上限、满血中心/受伤邻居治疗、全部满血时拒绝、存档读取和自动进入下一回合检查通过。

已目视检查菜单与目标控制截图。原版菜单数与按钮证据来自 bank 8 `$8F24–$903F` 静态反汇编，并非自然玩家菜单操作录像。更新后的提取 JSON 包含指令字节和各技术上限。

## 导出与真机检查

macOS 导出成功；导出可执行文件以默认入口无头启动 120 帧后退出码为 0。强制退出仍出现 ObjectDB/resource-in-use 警告，因此未声称长时间运行后可正常退出。Android 导出完成，保留编辑器关闭时已有的 scan-thread-aborted 警告；APK 校验与安装成功。

在小米 22021211RC（munch，API 33）上使用 `adb install -r`，保留了应用数据。启动别名 `com.godot.game.GodotAppLauncher` 正常启动。实际触屏依次完成：标题 → 菜单 → 读取已有第一关存档 → 选蓝色单位 → 单位命令 → 普通攻击 → 新目标按钮 → 按 B 取消。目标按钮显示正确的“附近没有敌人”提示，没有消耗行动。此流程日志没有 SCRIPT ERROR、Parse Error、FATAL EXCEPTION 或 ERROR: match。

既有存档 SHA-256 仍为 `2551eb37ba026d18b12ca0323971e83bd50d590b93be9274264069dc833c4859`，没有写入存档。旧存档没有能使用技术的单位，因此新技术菜单和实际施放只在可运行源码场景与触控处理器中验证，没有在真机技术战斗中覆盖。

原版菜单名称、辅助数据包字节的含义/资源消耗、零数值特殊效果、完整敌方变体选择、经验/升阶继承及原版技术动画仍未完成。目标快捷操作和子菜单布局属于复刻版界面。
