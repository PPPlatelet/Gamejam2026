# AI 使用与素材声明（CREDITS）

本文件同时作为比赛要求的《AI 使用与素材声明》，记录本仓库第三方素材、团队素材的来源与授权，以及 AI 工具的使用范围与人工修改情况。
最后更新：2026-11-22（素材来源已由团队成员确认）

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
| `assets/The_Lands/land1.jpg`、`land2.jpg`、`land1_NoEdge.png`、`land2_NoEdge.png` | 团队成员**自绘**（2026-11-22 确认） | 地图底图；已不再逐格铺设（背景改用 `fog_land.png`），文件保留备用 |
| `assets/The_Lands/fog_land.png` | 团队成员**自绘**（2026-11-22 确认） | 当前场景背景图，铺满屏幕；格子判定保留但不再显示地块/网格 |
| `assets/The_Lands/图层 1.png` ～ `图层 9.png` | 团队成员**自绘**（2026-11-22 确认） | 分层地图素材，当前未在场景中引用 |
| `assets/The_Lands/sea_map.png` | 团队成员**自绘**（2026-11-22 确认） | 海面预览图，仅用于 `scenes/preview_sea.tscn`，未接入正式关卡 |
| `assets/opening/*.png`、`opening/*.png` | 当前为 **DSH 生成**的临时版本（2026-11-22 确认） | 开场插画；计划替换为团队自绘版本，替换后更新本表 |
| `assets/opening/scroll.png` | 团队成员提供（2026-11-23，源文件 `卷轴.psd`） | 开场动画的卷轴底图，白底已扣成透明 |
| `assets/opening/scroll_frame.png` | 同上，由 `scroll.png` 加工 | 纸窗版卷轴：内部半透明，用于关卡开场时露出地图 |
| `assets/opening/scroll_frame_wide.png` | 同上，由 `scroll_frame.png` 旋转 90° | 横向卷轴纸窗素材（关卡开场从左往右铺开） |
| `assets/ui/cell_marker.png` | 团队成员提供（2026-11-23） | 放置单位时的青色六边形描边 |
| `assets/ui/ink_button.png` | 团队成员提供（2026-11-23，源文件 `水墨按键.psd`） | 左侧放船按钮的墨迹底图 |
| `assets/占位素材/*.png` | 本项目自产（AI 编写脚本 + 程序化绘制） | 由 `tools/make_placeholder_art.py`（Pillow）绘制的占位图；`tower_base.png`、`tower_turret.png` 已随旧塔删除而不再使用 |
| `docs/images/*.png` | 本项目自产 | 游戏运行截图 |
| `vn/first_level.json` | 本项目自产 | 剧情脚本（当前为空文件，待填写） |

除上表与第一节列出的内容外，项目中没有其他图片、音频、字体或第三方代码素材。

## 四、AI 使用记录

- 使用的 AI 工具：DeepSeek Harness（deepseek-flash 模型）等 AI 编程助手。
- AI 生成的内容：
  - GDScript 玩法代码、场景与节点结构、导出配置；
  - 占位美术的生成脚本（`tools/make_placeholder_art.py`，用 Pillow 程序化绘制）及其输出的占位图；
  - 开场插画的临时版本（后续替换为自绘）；
  - 剧情字幕的数据结构与文案初稿（`scripts/story_lines.gd`）；
  - 开发文档与运行截图；
  - 数值平衡的初版草案。
- 人工完成的部分：需求定义、玩法取舍与验收、地图/海面等美术素材自绘、开场插画的最终自绘版本、数值与手感的实机调整、代码审阅与合并。
- 未使用 AI 的内容：`fonts/ZhiMangXing.ttf`、`icon.svg`（第三方素材）、团队自绘素材（见第三节）。

## 五、赛前已有内容申报

- 代码与素材：本项目为本届比赛期间从零开发，未使用赛前完成的代码或美术素材。
- 开发工具（赛前已有，非作品内容）：Godot Engine 4.7（开源引擎）、DeepSeek Harness 等 AI 辅助工具。
- 第三方素材（赛前已有）：Zhi Mang Xing 字体、Godot 默认图标，授权见第一节。

## 六、比赛要求对照

- 原创与素材授权：见第一、三节；除字体与图标外，素材均为团队自绘或 AI 生成。
- AI 辅助声明：见第四节，包含工具、用途、生成内容与人工修改情况。
- 可运行发行版与启动说明、演示视频、开发者日志：不在本仓库文件内，按比赛要求在提交平台与 B 站另行提供。
- 本声明随仓库版本更新；开场插画替换为自绘后需同步更新第三节并移除对应 AI 生成条目。
