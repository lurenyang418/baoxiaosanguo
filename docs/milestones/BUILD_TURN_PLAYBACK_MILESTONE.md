# 逐步回合播放阶段记录｜2026-10-05

## 可运行构建包

本地 Debug 包位于 `build/turn-playback-milestone/`。保留了旧包和用户文件，没有删除、发布或改变签名策略。

| 产物 | 配置 |
|---|---|
| `BaoXiaoSanGuo.app` | macOS Debug Universal 2，arm64 + x86_64 |
| `baoxiaosanguo-debug.apk` | Android Debug ARM64，88,914,956 字节 |
| `checksums.json` | APK、可执行文件和 PCK 的 SHA-256 与大小 |
| `hp-change-preview.png` | 敌方攻击后的源码场景，显示 −20 HP |
| `android-action-playback.png` | 真机显示行动 1/4 和纵向镜头跟随 |
| `android-after-skip-round18.png` | 按 A 快进后真机显示第 18 回合 |
| `android-second-turn-combat.png` | 下一回合真机播放原版步兵战斗动画 |
| `android-round19.png` | 该回合结束后真机显示第 19 回合 |

APK SHA-256：`ece08084b2191e1a58a6913c35bf74a3ea91b952e16f5397ed80d996ecc91d87`。Build Tools 36.0.0 的 Signature Scheme v2 校验通过。沿用原 Debug 包名、版本 0.1.0/代码 1 和 SDK 配置。

从项目根目录构建：

```sh
BAOXIAO_BUILD_DIR="$PWD/build/turn-playback-milestone" ./scripts/build_macos.sh
BAOXIAO_BUILD_DIR="$PWD/build/turn-playback-milestone" ./scripts/build_android.sh
```

## 实现流程

- 按现有 AI 顺序记录自动友军/敌军的实际行动：group1 友军先于 group2 敌人，敌人仍按槽位降序行动。
- 使用现有纵向滚屏规则跟随行动单位；先突出行动者，再依次显示新位置和受影响单位的 HP 变化。
- 攻击/治疗演出与对应行动绑定，避免所有演出都在最终地图状态上排队播放。
- 权威战斗状态与显示快照分离。播放不会再次消耗行动、修改经验或重复执行 AI。
- 播放期间锁定普通命令；键盘/手柄确认和 Android A 可安全快进剩余阶段。
- 自动阶段播放完毕后才显示胜败。用 A 跳过致命行动不会同时误触结果面板。
- 关闭战斗动画时，地图行动仍会短暂依序播放，但省略漫画面板和回合跑动角色；仍可按 A 快进。

## 检查结果

临时可运行探针检查（非永久仓库测试）：

- 全部 19 关初始配置：最终位置/HP 与原 AI 逻辑直接执行相符；确认友军先于敌军、敌军槽位降序、立即锁定输入，且快进只推进一次回合。
- 受控第一关攻击：独立显示 HP、一段攻击演出、完整播放、HP 变化、触控 A 快进及最终快照值。
- 受控敌方群体治疗/休息：治疗演出与正确行动绑定，休息仍是独立记录的行动。
- 受控玩家阵亡伤害和友军最终击杀：播放结束前保持终局结果未确认；快进不会离开战场场景。
- 既有经验/升阶探针通过，涵盖旧存档、升级选择、自动成长、战役继承和失败重试。

macOS 导出默认入口无头运行 120 帧后退出码为 0；可执行文件包含原生 arm64 和 x86_64。源码画面已目视检查。强制退出仍有 ObjectDB/resource-in-use 警告，Android 导出仍有编辑器 scan-thread-aborted 关闭警告。

小米 22021211RC/munch（API 33）通过 `adb install -r` 安装，读取真实已有的第 17 回合存档，选择“全军休息”，观察敌方移动及行动 1/4；按 A 快进并确认第 18 回合。再次“全军休息”后观察原版步兵战斗动画，等待播放完成并确认第 19 回合，然后取消菜单。日志未发现 SCRIPT ERROR、Parse Error、FATAL EXCEPTION 或 ERROR: match。没有写入旧存档，其 SHA-256 仍为 `2551eb37ba026d18b12ca0323971e83bd50d590b93be9274264069dc833c4859`。

## 还原度限制

本阶段让现有 AI 决策过程可见，但不能证明所有 AI 分支都准确，也不能证明全部 19 关均可通关。时长、行动者轮廓、数值 HP 反馈和快进界面属于复刻版行为。移动播放展示现有算法的目的地，未重建原版逐格步行动画/路径。高阶兵种战斗美术、技术/状态效果和敌方经验仍未完成。本次未在 Android 真机检查治疗、成长或完整战役。
