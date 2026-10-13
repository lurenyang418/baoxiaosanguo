# ROM 逆向资料目录

主要研究记录见[ROM_RESEARCH.md](ROM_RESEARCH.md)，主题索引见[研究索引](../docs/RESEARCH.md)。原版 ROM 和说明书保留在本仓库之外；工具通过命令行接收 ROM 路径，不在仓库中保存 ROM 副本。

## 原版 ROM 参考版本

当前逆向记录以简体中文版为基准：
`BaoXiaoSanGuo(ES1005)(ChS)(970261).nes`。
文件大小为 1,048,592 字节，SHA-256 为
`c3f6f08c08e325f41b0c683ad24096053753a94b9a1e6c4bda34dac13139a13f`。
运行提取工具时把本地 ROM 路径作为参数传入即可。仓库只记录文件名和校验值，
不保存 ROM 内容；这样可以核对本地研究输入，同时避免把整份游戏 ROM 放进 Git
历史或发布包。

## 目录说明

- `tools/extract/`：从 ROM 提取战场、武将、成长、技术和图形数据。
- `tools/render/`：将提取结果渲染为地图、图集和素材预览。
- `tools/fceux/`：可在 FCEUX 中运行的 Lua 调试与跟踪脚本。
- `tools/maintenance/`：校验、转换和辅助维护脚本。
- `evidence/images/`：原版模拟器截帧和复刻版运行截图，不参与游戏运行。
- `evidence/movies/`：FCEUX 输入录制文件（FM2）。
- `evidence/records/`：解码记录、实验说明及结构化分析结果。
- `evidence/traces/`：模拟器输出的 RAM 快照、逐帧轨迹和实验结果。

## 工具约定

大多数 Python 工具从仓库根目录执行，输入原版 ROM 路径，并把可供游戏使用的 JSON 写入 `data/`，把运行素材或调试预览图写入 `assets/rom_reference/`。该目录不是 ROM 文件备份：其中一部分由游戏运行时代码加载，另一部分供 ROM 预览场景和提取工具使用。运行前请阅读脚本帮助或研究日志里的对应步骤。

FCEUX Lua 脚本的默认输出位置是 `research/evidence/traces/`，也可以通过环境变量 `FCEUX_TRACE_OUTPUT` 指定输出文件。脚本使用相对于仓库根目录的路径时，请从仓库根目录启动 FCEUX。

`data/` 中只有游戏代码运行时读取的 9 份 JSON；证据档案和实验结果集中保存在本目录。这里的 `.gdignore` 用于避免 Godot 扫描研究工具和资料，同时文件仍由 Git 管理。
