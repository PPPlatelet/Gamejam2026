class_name VnStory
extends RefCounted

## 视觉小说的「剧本」数据。
##
## 一个剧本 = 标题 + 若干页；每一页 = 一种颜色 + 说话人 + 一段文字。
## 内容一般写在 res://vn/*.json 里（方便策划 / 文案直接改），
## 由 VnStory.from_json_file() 读成这个对象，再交给 VN.open_story() 播放。
##
## 也可以完全不用 JSON，直接传字典：
##   VN.open({"title": "标题", "pages": [{"color": "red", "text": "第一页的字"}]})

## 三页对应的三种颜色：红 / 黄 / 白。
const PAGE_COLORS := {
	"red": {"color": Color(0.847, 0.271, 0.235), "label": "红"},
	"yellow": {"color": Color(0.949, 0.757, 0.306), "label": "黄"},
	"white": {"color": Color(0.969, 0.961, 0.945), "label": "白"},
}
const FALLBACK_COLOR := "white"

var title := ""
## 每页的结构：
## {
##   "color": Color,         页面底色
##   "color_key": String,    red / yellow / white / custom
##   "color_label": String,  红 / 黄 / 白，自定义颜色时为空
##   "speaker": String,      说话人，空字符串表示不显示
##   "text": String          这一页要逐字显示的文字（可以有换行）
## }
var pages: Array[Dictionary] = []


## 从 JSON 文件读取剧本。失败时返回 null，并在控制台说明是哪一行出错。
static func from_json_file(path: String) -> VnStory:
	if not FileAccess.file_exists(path):
		push_error("视觉小说：找不到剧本文件 %s" % path)
		return null

	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("视觉小说：%s 第 %d 行 JSON 语法错误 —— %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("视觉小说：%s 最外层必须是 { } 包起来的一个对象" % path)
		return null

	var story := from_dict(json.data)
	if story != null and story.title.is_empty():
		story.title = path.get_file().get_basename()
	return story


## 从字典读取剧本。失败时返回 null。
static func from_dict(data: Dictionary) -> VnStory:
	var story := VnStory.new()
	story.title = str(data.get("title", ""))

	var raw_pages = data.get("pages", null)
	if typeof(raw_pages) != TYPE_ARRAY or (raw_pages as Array).is_empty():
		push_error("视觉小说：剧本需要非空的 \"pages\" 数组")
		return null

	var page_number := 0
	for raw in raw_pages:
		page_number += 1
		if typeof(raw) != TYPE_DICTIONARY:
			push_error("视觉小说：第 %d 页应该是一个 { }" % page_number)
			return null

		var page_text := ""
		if raw.has("lines"):
			if typeof(raw["lines"]) != TYPE_ARRAY:
				push_error("视觉小说：第 %d 页的 \"lines\" 应该是数组" % page_number)
				return null
			var parts := PackedStringArray()
			for line in raw["lines"]:
				parts.append(str(line))
			page_text = "\n".join(parts)
		elif raw.has("text"):
			page_text = str(raw["text"])

		if page_text.strip_edges().is_empty():
			push_error("视觉小说：第 %d 页没有文字（text / lines 都是空的）" % page_number)
			return null

		var color_info := _parse_color(str(raw.get("color", FALLBACK_COLOR)))
		story.pages.append({
			"color": color_info.color,
			"color_key": color_info.key,
			"color_label": color_info.label,
			"speaker": str(raw.get("speaker", "")),
			"text": page_text,
		})

	return story


func page_count() -> int:
	return pages.size()


func page_at(index: int) -> Dictionary:
	if pages.is_empty():
		return {}
	return pages[clampi(index, 0, pages.size() - 1)]


## 颜色可以写 red / yellow / white，也可以写 #RRGGBB。
static func _parse_color(raw: String) -> Dictionary:
	var text := raw.strip_edges()
	var key := text.to_lower()
	if PAGE_COLORS.has(key):
		var entry: Dictionary = PAGE_COLORS[key]
		return {"color": entry.color, "key": key, "label": entry.label}

	if text.begins_with("#"):
		var custom := Color.from_string(text, Color(0, 0, 0, 0))
		if custom.a > 0.0:
			return {"color": custom, "key": "custom", "label": ""}

	push_warning("视觉小说：不认识的页面颜色 \"%s\"，改用白色（可写 red / yellow / white 或 #RRGGBB）" % raw)
	var fallback: Dictionary = PAGE_COLORS[FALLBACK_COLOR]
	return {"color": fallback.color, "key": FALLBACK_COLOR, "label": fallback.label}
