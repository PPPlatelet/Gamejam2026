class_name SongFont
extends RefCounted

## 项目统一的中文宋体：Noto Serif SC（思源宋体，OFL 1.1）。
## 文件是可变字体，默认实例偏细，所以按字重取一个 FontVariation 实例。
const FONT_FILE := preload("res://fonts/NotoSerifSC-VF.ttf")


static func make(weight := 400.0) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = FONT_FILE
	font.variation_opentype = {"wght": weight}
	return font
