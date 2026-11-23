## 屏幕上的剧情字幕：一次显示一条，自动淡入淡出；多条触发时排队依次播。
## 不用底色，黑字直接压在画面上，字体沿用 fonts/ZhiMangXing.ttf。
## 位置、"出现在哪"由剧本里每条的 "where" 决定：top / center / bottom / left / right。

extends Control

const CAPTION_FONT := preload("res://fonts/ZhiMangXing.ttf")
const FONT_SIZE := 30
const LINE_GAP := 8.0
const PAD_X := 24.0
const PAD_Y := 16.0
const FADE_IN := 0.3
const FADE_OUT := 0.6
const TEXT_COLOR := Color(0.05, 0.05, 0.05)

var _font: Font = CAPTION_FONT
var _queue: Array = []
var _text := ""
var _where := "bottom"
var _duration := 5.0
var _elapsed := 0.0
var _active := false
var _lines := PackedStringArray()
var _box_size := Vector2.ZERO
var _line_height := 30.0
var _at := Vector2(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


## where 用预设位置；at 是自定义位置（屏幕比例 0~1，字幕框中心对准这个点）。
func show_line(text: String, where: String, seconds: float, at := Vector2(-1, -1)) -> void:
	_queue.append({"text": text, "where": where, "seconds": seconds, "at": at})
	if not _active:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_active = false
		_text = ""
		_lines = PackedStringArray()
		queue_redraw()
		return

	var item: Dictionary = _queue.pop_front()
	_text = str(item.get("text", ""))
	_where = str(item.get("where", "bottom"))
	_at = item.get("at", Vector2(-1, -1))
	_duration = maxf(1.0, float(item.get("seconds", 5.0)))
	_elapsed = 0.0
	_active = true
	modulate.a = 0.0
	_rebuild()
	queue_redraw()


func _rebuild() -> void:
	var max_width := 980.0 if _where == "top" or _where == "bottom" else 640.0
	if _at.x >= 0.0:
		max_width = 640.0
	_lines = _wrap(_text, max_width)
	_line_height = _font.get_height(FONT_SIZE) + LINE_GAP
	var widest := 0.0
	for line in _lines:
		widest = maxf(widest, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var height := _lines.size() * _line_height - LINE_GAP
	_box_size = Vector2(widest + PAD_X * 2.0, height + PAD_Y * 2.0)


func _wrap(text: String, max_width: float) -> PackedStringArray:
	var result := PackedStringArray()
	for paragraph in text.split("\n"):
		var current := ""
		for i in paragraph.length():
			var ch := paragraph[i]
			var candidate := current + ch
			if current != "" and _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > max_width:
				result.append(current)
				current = ch
			else:
				current = candidate
		result.append(current)
	return result


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	var alpha := 1.0
	if _elapsed < FADE_IN:
		alpha = _elapsed / FADE_IN
	elif _elapsed > _duration - FADE_OUT:
		alpha = maxf(0.0, (_duration - _elapsed) / FADE_OUT)
	modulate.a = alpha
	if _elapsed >= _duration:
		_next()
	queue_redraw()


func _draw() -> void:
	if not _active or _text.is_empty():
		return
	var view := get_viewport_rect().size
	var origin := _box_position(view)
	var y := origin.y + PAD_Y + _font.get_ascent(FONT_SIZE)
	for line in _lines:
		var line_width := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var x := origin.x + (_box_size.x - line_width) * 0.5
		draw_string(_font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
		y += _line_height


func _box_position(view: Vector2) -> Vector2:
	if _at.x >= 0.0 and _at.y >= 0.0:
		return Vector2(view.x * _at.x, view.y * _at.y) - _box_size * 0.5
	match _where:
		"top":
			return Vector2((view.x - _box_size.x) * 0.5, view.y * 0.075)
		"bottom":
			return Vector2((view.x - _box_size.x) * 0.5, view.y * 0.86 - _box_size.y)
		"left":
			return Vector2(view.x * 0.035, view.y * 0.16)
		"right":
			return Vector2(view.x * 0.965 - _box_size.x, (view.y - _box_size.y) * 0.5)
		_:
			return (view - _box_size) * 0.5
