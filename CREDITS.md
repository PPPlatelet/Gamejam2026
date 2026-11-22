# 素材来源、许可与 AI 使用记录

本文件用于比赛提交与团队内部核对，记录仓库中第三方素材、团队素材的来源与授权，以及 AI 工具的使用范围。
最后更新：2026-11-22

## 一、第三方素材

| 文件 | 作者 / 来源 | 许可证 | 署名与义务 | 用途 |
|---|---|---|---|---|
| `fonts/ZhiMangXing.ttf` | Zhi Mang Xing Project Authors，Google Fonts（<https://fonts.google.com/specimen/Zhi+Mang+Xing>） | SIL Open Font License 1.1，全文见 `fonts/OFL.txt` | 分发时随附 OFL 许可证与版权声明；字体本身不得单独售卖；衍生字体不得使用保留字体名 | 游戏内剧情字幕 |
| `icon.svg` | Godot Engine logo，Copyright 2017 Andrea Calabró | CC BY 4.0（<https://github.com/godotengine/godot/blob/master/LOGO_LICENSE.md>） | 署名 "Godot Engine logo © 2017 Andrea Calabró, CC BY 4.0" | 项目图标（Godot 默认图标） |

## 二、引擎与第三方代码

- Godot Engine 4.7，MIT License（<https://godotengine.org/license>）：项目运行依赖，未修改引擎源码。
- 未引入其他第三方库或插件。`shaders/vignette.gdshader` 与全部 GDScript 为本项目自写。

## 三、团队素材

| 文件 | 来源 | 说明 |
|---|---|---|
| `assets/The_Lands/land1.jpg`、`land2.jpg`、`land1_NoEdge.png`、`land2_NoEdge.png` | 团队成员提供 | 地图底图；当前用 `land2_NoEdge.png` 作格子贴图 |
| `assets/The_Lands/图层 1.png` ～ `图层 9.png` | 团队成员提供 | 分层地图素材，当前未在场景中引用 |
| `assets/The_Lands/sea_map.png` | 团队成员提供（2026-11-22） | 海面预览图，仅用于 `scenes/preview_sea.tscn`，未接入正式关卡 |
| `assets/opening/*.png`、`opening/*.png` | 团队成员提供 | 开场插画（两处为同一组图的副本） |
| `assets/占位素材/*.png` | 本项目自产 | 由 `tools/make_placeholder_art.py`（Pillow）程序化绘制的占位图，原创；`tower_base.png`、`tower_turret.png` 已随旧塔删除而不再使用 |
| `docs/images/*.png` | 本项目自产 | 游戏运行截图 |
| `vn/first_level.json` | 本项目自产 | 剧情脚本（当前为空文件，待填写） |

## 四、AI 使用记录（比赛声明用）

- 使用的 AI 工具：DeepSeek Harness（deepseek-flash 模型）等 AI 编程助手。
- 使用范围：
  - GDScript 玩法代码、场景与节点结构、导出配置；
  - 占位美术的生成脚本（`tools/make_placeholder_art.py`，用 Pillow 程序化绘制）；
  - 剧情字幕的数据结构与文案初稿（`scripts/story_lines.gd`）；
  - 开发文档与运行截图；
  - 数值平衡的初版草案。
- 人工工作：需求定义、玩法取舍与验收、地图/开场等美术素材的提供、数值与手感的实机调整、代码审阅与合并。
- 未使用 AI 的内容：`fonts/ZhiMangXing.ttf`、`icon.svg`（第三方素材，见第一节）。

## 五、待团队确认

以下条目需要素材提供者确认后再更新本文件；确认前不建议对外声明为已完成：

- [ ] `assets/The_Lands/` 中 land1/land2 与 图层 1–9 的原始来源与授权（自绘 / 购买 / AI 生成），以及是否允许用于本次比赛。
- [ ] `assets/opening/`、`opening/` 开场插画的作者与授权。
- [ ] `sea_map.png` 的来源与授权。
- [ ] 若比赛要求逐文件声明，按上表补全每个文件的生成工具 / 作者。
