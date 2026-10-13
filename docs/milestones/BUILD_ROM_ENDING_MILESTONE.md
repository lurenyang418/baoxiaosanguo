# 原版结局阶段记录｜2026-10-06

> 历史记录：此阶段曾将 ROM 结尾故事画面和员工名单接入 Godot。当前运行版本已换成原创胜利庆祝场景；本文件保留当时的逆向证据与实现记录，不代表当前结尾画面。

## 功能变化

第 19 关胜利后会打开 `scenes/rom_ending.tscn`。5 张原版故事画面自动播放，随后是 7 页制作人员名单，可按 A、Start 或触控翻页；最后播放原版终幕。按 B/Escape 可跳到通关记录。记录页可用 R、手柄 Y 或触控链接重播结局。保存或读取通关记录仍直接进入记录页。

`assets/rom_reference/ending/` 中 43 张源图为从提供的原版 ROM 截取的 256×240 画面，不是手绘替代图。中间动画、准确眨眼节奏和配乐尚未还原；底部帮助提示是复刻版 UI。

## ROM 证据

`research/tools/fceux/fceux_final_victory_trace.lua` 记录了受控分支：从已有第 0 关录制开始，在第 3900 帧将 `$6400` 设为 18 并清除 group-2 敌人。FCEUX 随后在第 4012 帧到达 `$6400=19`，映射地址 `$8000` 出现 `4C 06 80`，对应物理 PRG bank 42 的 callback 0。故事 5 页按每 100 帧从 4100 到 6300 采样；另一次无输入运行在第 6500 帧采到自动“完”转场。第 6700 至 12700 帧的 7 次 A 输入推进名单；第 13000 至 15000 帧出现最终动画和 START 标志。采样信息与限制见 `research/evidence/records/rom_ending_capture.json` 和[研究日志](../../research/ROM_RESEARCH.md)。

这证明原版在最终分支后绘制这些结局画面。由于实验注入了关卡索引和敌方全灭状态，因此不能证明复刻版可以自然完成全部 19 关。

在项目根目录并备好原版 ROM 与第 0 关录制后，可复现受控采样：

```sh
fceux --sound 0 --no-config --loadstate 99 --savestate 99 \
  --playmov "$PWD/research/evidence/movies/fceux_stage00_seven_phases.fm2" \
  --loadlua "$PWD/research/tools/fceux/fceux_final_victory_trace.lua" \
  '../BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes'
python3 research/tools/maintenance/convert_fceux_gd.py \
```

## 验证情况

- Godot 4.7.2 成功导入截取的 PNG 并解析结局场景。
- 隔离运行从第 19 关胜利进入结局，播放自动故事和 7 页名单，进入终幕与通关记录，保存、重播、按 B 跳过，再从标题读取记录。
- macOS Godot 窗口显示了 256×240 故事、名单与终幕。

最终构建在 `build/rom-ending-milestone-final/`；较早的 `build/rom-ending-milestone/` 尚不含无输入“完”画面。macOS Debug App 含 `arm64` 和 `x86_64`，内置可执行文件无头启动并正常退出。ARM64 Android Debug APK 的 `apksigner verify` v2 校验通过。APK SHA-256：`85f9feb53ee2b32305b9f171d0c1cabca4de4cc3a1f510066ed684ffd2ac1453`。当时没有连接 ADB 设备，因此未安装到手机。旧构建和用户存档均保留。
