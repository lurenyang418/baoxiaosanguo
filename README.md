# 爆笑三国 Godot 复刻

这是基于原版 FC ROM 资料制作的跨平台复刻项目，目标平台为 Apple Silicon macOS、Windows x64、Android ARM64 和 iOS。游戏采用 256×240 的 NES 逻辑画面，当前已串联 19 关，并包含原版开场、战斗、存档和通关流程。

项目仍在开发中：部分战斗规则、敌方行为、画面细节、音乐对应关系和结局动画尚未完全还原。地图、部署、兵种数据、移动力及若干战斗逻辑已根据 ROM 资料整理。请把它视为可玩的复刻原型，而非 100% 的原版复现。

## 快速开始

使用 Godot 4.7.2 打开本目录中的 `project.godot`，在编辑器中按 F5 启动。也可以在项目根目录运行：

```sh
godot --path .
```

首次打开项目时，Godot 会导入图片资源。命令行无界面导入方式：

```sh
godot --headless --editor --import --path .
```

## 操作方式

- 方向键或手柄十字键：移动光标
- A：打开或确认命令
- B 或 Esc：取消
- Start 或 Enter：打开系统菜单
- F7、F8：打开独立的 ROM 战斗演示切片；再次按对应按键返回
- 触屏：点按地图移动光标，竖向滑动地图滚屏；屏幕两侧提供方向键和 A/B/菜单按钮

系统菜单中的“储存进度”和“读取进度”保存或恢复当前复刻进度，存档位于 Godot 的应用数据目录。这不是 NES 模拟器存档。

## 构建

导出预设位于 `export_presets.cfg`，构建产物写入仓库根目录的 `build/`；Android 安装包单独放在 `build/android/`：

```sh
./scripts/build_macos.sh             # macOS 调试版
./scripts/build_macos.sh --release   # macOS 本地测试 DMG（ad-hoc 签名）
./scripts/build_windows.sh           # Windows x64 调试版
./scripts/build_android.sh           # Android 调试版 APK
./scripts/build_android.sh --release # Android Release APK（本机安装/侧载）
./scripts/build_ios.sh               # 生成 iOS Xcode 工程
```

iOS 工程需在 macOS 的 Xcode 中配置签名后才能安装到设备。完整依赖、导出步骤和发布前检查见[构建指南](docs/BUILD.md)。

## 项目目录

- `scenes/`：游戏场景
- `scripts/`：Godot 游戏逻辑及构建脚本
- `assets/`：游戏画面、音频和图标资源；`assets/rom_reference/` 中保留运行素材及 Godot 调试场景所需的 ROM 图集
- `data/`：运行时读取的 ROM 派生 JSON 数据
- `research/`：逆向记录、证据文件（含不参与游戏运行的截图），以及按用途分类的提取和分析工具
- `docs/`：构建说明、研究索引和阶段记录
- `build/`：本地导出的安装包；Android APK/AAB 放在 `build/android/`，整个目录已加入 Git 忽略规则

研究资料和工具也保存在仓库中，便于复核数据来源和重建提取结果；原版 ROM 与说明书保留在仓库之外。`research/.gdignore` 与 `docs/.gdignore` 可避免 Godot 导入这些研究文件。

## ROM 研究

- [玩法与战役系统](docs/GAMEPLAY_SYSTEMS.md)：将手册规则与已确认 ROM 行为对照整理
- [ROM 技术细节](docs/ROM_TECHNICAL_DETAILS.md)：卡带、地图/兵种数据、程序流程和实验依据
- [兵种与技术参考](docs/CLASS_AND_TECHNIQUE_REFERENCE.md)：成长路径、技术变体及资料冲突
- [研究日志](research/ROM_RESEARCH.md)：ROM 地址、数据结构、实验过程和已知限制
- [研究目录说明](research/README.md)：证据和工具的组织方式
- [研究索引](docs/RESEARCH.md)：按游戏功能查找对应资料
- [19 关地图图集](docs/map-gallery/)：直接浏览各关候选地图及总览图
- [阶段记录](docs/milestones/README.md)：已完成阶段、验证范围和历史构建记录
- [开场与音乐说明](docs/INTRO_AUDIO.md)

旧版英文 README 的详细阶段说明保存在 [docs/archive/README_EN.md](docs/archive/README_EN.md)，供查阅历史记录。
