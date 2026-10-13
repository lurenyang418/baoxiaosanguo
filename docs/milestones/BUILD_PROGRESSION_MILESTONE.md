# 经验与升阶阶段记录｜2026-10-05

## 构建产物

最终包位于 `build/progression-milestone-final/`。保留了早期包、中间版成长构建及用户文件，没有删除文件。macOS 和 Android 使用相同最终游戏源码导出本地 Debug 包，没有公开发布或上传。

| 产物 | 配置 |
|---|---|
| `BaoXiaoSanGuo.app` | macOS Debug Universal 2，arm64 + x86_64 |
| `baoxiaosanguo-debug.apk` | Android Debug ARM64，88,912,312 字节 |
| `checksums.json` | APK、可执行文件和 PCK 的 SHA-256 与大小 |
| `promotion-preview.png` | 实际 101 EXP 升阶分支选择画面 |
| `android-legacy-save-exp.png` | 真机旧存档单位与 EXP 显示 |

APK SHA-256：`0bf6ddade60834d652ed54484fc3da42a4f9fb591fd2d608b8c41a89538a5113`。Build Tools 36.0.0 的 APK Signature Scheme v2 校验通过。包名 `com.example.baoxiaosanguo`、版本 0.1.0/代码 1、min SDK 24/target SDK 34 未变。macOS 二进制包含原生 arm64 与 x86_64。

从项目根目录重建：

```sh
BAOXIAO_BUILD_DIR="$PWD/build/progression-milestone-final" ./scripts/build_macos.sh
BAOXIAO_BUILD_DIR="$PWD/build/progression-milestone-final" ./scripts/build_android.sh
```

## 游戏功能与原版 ROM 证据

临时可运行场景探针通过：

- 第一关实际初始 EXP 为 `[60,95,90]`；1 号槽单位完成攻击 +3 和击杀 +3 后达到 101，可看到原版三个分支 `[1,3,5]`。
- 选择骑兵会保留已损失的 20 HP：当前/上限从 80/100 变成 130/150。EXP 182 时自动从 type1 升到 type2 也保留这 20 点损失。
- JSON 存档与新场景可恢复升阶后的兵种、HP、累计 EXP 和已行动状态。负 EXP 或无法到达的兵种值会被拒绝，不会部分写入状态。
- 胜利后队伍兵种与 EXP 会继承到下一关部署；之后的自选队伍可正确读取已成长的槽位。
- 不含成长字段的 Android version 1 存档可载入并使用初始 EXP；新增字段保持 version 1 兼容性。
- 五目标击杀技术获得一次基础 5 EXP 加五次击杀奖励各 3，达到 1200 并使默认 type62 升为 63。恢复技术只获得一次基础技术经验，不拿击杀奖励。
- 最后一个单位的升阶选择会延后敌方回合，确认后只推进一次。触控选择的弓兵完成最终击杀后才进入下一关。
- 失败重试会丢弃未保存的战斗成长，恢复关卡初始状态。
- 开启成长后，技术选择/目标切换、群体治疗、存档和回合回归检查均通过。

分支面板已渲染并目视检查。静态解码提供比较阈值、分支目标、奖励偏移和损失 HP 保留规则。受控 FCEUX 效果轨迹记录 EXP280→285→288→291，确认一次技术基础奖励和两次独立击杀奖励。这不是自然升阶输入记录或完整战役录像。详情见[研究日志](../../research/ROM_RESEARCH.md)、[成长数据](../../data/rom_progression.json)和[经验轨迹](../../research/evidence/traces/rom_experience_effect.tsv)。

## 导出与 Android 真机检查

两个平台均导出成功。macOS 默认入口无头运行 120 帧后状态码为 0；强制退出仍有 ObjectDB/resource-in-use 警告。Android 导出仍有编辑器关闭时的 scan-thread-aborted 警告，安装和签名校验通过。

小米 22021211RC/munch（API 33）通过 `adb install -r` 安装，经 `com.godot.game.GodotAppLauncher` 启动，打开读取菜单并读取已有第一关存档。实际触屏打开蓝色单位命令，详情显示 `战士 HP100/100 · 移2 · EXP90`；随后取消菜单，没有执行行动。日志中没有 SCRIPT ERROR、Parse Error、FATAL EXCEPTION 或 ERROR: match。

既有存档 SHA-256 未变：`2551eb37ba026d18b12ca0323971e83bd50d590b93be9274264069dc833c4859`。没有写入存档。Android 真机未检查实际升阶或战役成长；这些流程在可运行场景检查。音频、全部 19 关和长时间运行也未覆盖。

原版升阶画面/动画、自然升阶输入记录、友军/敌军自动 EXP、完整敌方 AI 和技术特殊效果仍未完成。游戏中的升阶分支面板是复刻版 UI。
