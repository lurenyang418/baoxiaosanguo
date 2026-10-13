# 战术操作阶段记录｜2026-10-06

## 构建产物

最终本地 Debug 包位于 `build/tactics-milestone-final/`；早期 `tactics-milestone/` 等构建保留。没有删除、发布、改版本或改变签名策略。

| 产物 | 配置 |
|---|---|
| `BaoXiaoSanGuo.app` | macOS Debug Universal2，原生 arm64 与 x86_64 |
| `baoxiaosanguo-debug.apk` | Android Debug ARM64，88,921,308 字节 |
| `checksums.json` | APK、macOS 可执行文件与 PCK 的大小和 SHA-256 |
| `enemy-info.png`、`cavalry-info.png`、`scholar-info.png` | 源场景单位详情面板 |
| `cavalry-range.png` | 升阶后 type1 的受控移动范围 |
| `attack-preview.png`、`acted-marker.png` | 伤害上限预览和已行动标记 |
| `source-checks.log` | 最终可运行源码探针输出 |

APK SHA-256：`477fa9528e7787344f46b079c02dde08b517120cd641b9a9a87e164b200abe50`。Build Tools 36.0.0 的 APK Signature Scheme v2 校验通过。Debug 包名 `com.example.baoxiaosanguo`、版本 0.1.0/代码 1 和 SDK 配置保持不变。

从项目根目录构建：

```sh
BAOXIAO_BUILD_DIR="$PWD/build/tactics-milestone-final" ./scripts/build_macos.sh
BAOXIAO_BUILD_DIR="$PWD/build/tactics-milestone-final" ./scripts/build_android.sh
```

Android 首次导出因 Godot 未设置 Java SDK 路径而失败；定位到已安装的 Temurin 17 后，仅补上空的编辑器设置 `/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home`，随后两个导出均成功。旧设置已在本机备份。新机器仍需按 `BUILD.md` 配置自己的 Java/Android SDK；这些本机路径不是仓库凭据。

## 游戏功能变化

### 实时移动力

`_selected_movement_points()` 之前读取关卡初始 `player_deployments`，导致成长后的单位和自选队伍仍用初始移动力。现在依据当前 `unit_type_ids`，通过 ROM 提取定义 byte7/$66BF 查询移动力。

移动范围、无效目标提示、可接受目的地、命令文字和详情面板共用同一数值。骑兵 type1 为 3、type2 为 4；学者 62→63 时为 4→5。存档读取和后续部署使用恢复后的当前兵种。没有新增或修改移动力/属性表。

### 单位详情与行动导航

- 闲置时按键盘 I、触控“单位详情”或手柄 Back/View 可查看光标单位。A 点选敌人、自动友军或已行动玩家单位时也打开相同面板；未行动玩家单位按 A 仍打开命令菜单。
- 详情显示阵营、当前兵种、HP 条、攻击、防御、移动力、行动状态，以及玩家 EXP/下一个比较门槛。支持的技术行显示数值、范围形状和距离；尚不可用的特殊效果会标明。敌方治疗采用单独提取的目标覆盖表。
- 方向键或 C/V 浏览存活且可见的单位。A/B、I、手柄 Back/View、“返回战场”或面板页脚可关闭详情；查看信息不消耗行动。
- 闲置时 C/V、手柄 X/Y 和触控“待行动”轮换未行动玩家单位；跳过阵亡或已行动单位，既有纵向镜头会跟随。
- 闲置 HUD 显示关卡、回合、剩余行动数和存活敌人。已行动玩家单位仍显示蓝色阵营色，同时变暗并加小勾。
- type1 在地图上沿用现有蓝色骑乘姿势与通用战斗面板。其他高阶兵种美术仍为临时方案，尚未完成精灵图还原。

### 普通攻击伤害预览

合法的相邻目标会显示当前/最大 HP、预计实际损失、剩余 HP 和是否击败。预测调用已有 ROM 伤害函数，并将显示伤害限制为目标当前 HP。确认后，实际损失也传给战斗演出/状态文字。伤害、击杀奖励和 EXP 规则不变；不合法位置不会显示误导性的合法目标预览。

## 已完成的检查

临时可运行源码探针（并非永久仓库测试）检查了：

- 全部 19 关初始部署的移动力符合当前 ROM 兵种；自动阶段锁定输入，按 A 快进后位置、HP 和回合数符合最终结算。
- 实际升阶 0→1 后移动力从 2 变 3：允许移动 3 格，不允许 4 格；存档/新场景恢复 3；type1→2 使用 4。
- 有奖励的攻击打开真实升阶分支面板；选择骑兵后立即显示 3 格移动力。
- 首个骑兵敌人的详情属性为攻击 110、防御 105、移动 3。详情导航、关闭、查看已行动玩家和触控按钮不会改变 HP、EXP、已行动状态或回合数。
- 可行动单位轮换会跳过阵亡/已行动单位。手柄 Back/View 可打开关闭详情，也仍可取消命令菜单。
- 目标有 10 HP、公式伤害为 16 时，预览显示伤害 10/剩余 0；确认后扣除 10，并排入显示 10 点伤害的演出。
- 25 号技能保留明确的三行技术菜单；取消不消耗行动。

更早还完成了成长、技术和逐步回合探针。已目视检查最终源码渲染。导出的 macOS 默认入口无头运行 120 帧后退出码为 0，架构确认包含两种原生架构；也曾打开真实窗口并查看标题画面。但自动键鼠未能推进标题，因此不能声称已验证打包版战斗操作。导出模板不支持命令行场景覆盖，也不能运行编辑器式外部脚本探针。

APK 签名校验成功。当时 ADB 未连接设备，因此本版未安装或在手机上操作；没有读取或写入设备存档。此前逐步回合版本的 Android 验收不能替代本版缺失的检查。强制关闭源码/App 仍有 ObjectDB/resource-in-use 警告；Android 导出仍有 editor scan-thread-aborted 警告。最终源码探针没有报告 SCRIPT ERROR、Parse Error 或断言失败。

## 尚未完成

详情面板、HUD、伤害预览、变暗和导航均为复刻版 UI。ROM 兵种 56–71 的名称仍显示“部队+ID”；骑兵复用了既有骑乘姿势，没有新的运行时美术证据。完整 AI、高阶地图/战斗美术、特殊技术和全 19 关通关仍未完成。Android 真机触控与真机升阶移动还需设备检查。
