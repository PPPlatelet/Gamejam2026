extends Control

## 关卡开始动画：先出关卡名，然后横向卷轴从左往右铺开，
## 纸窗里一点点露出已经布好的地图（带网格，方便认格子）；铺开完卷轴和暗场一起淡出。
##
## 由 game.gd 在开局时套一层 CanvasLayer 实例化，播完发 finished 信号；
## 播放期间游戏主循环不推进（game.gd 里的 _intro_playing），所以 15 分钟从 0 开始算。
## 左键 / 空格 / 回车 / Esc 可以跳过。

signal finished

const TITLE_FONT := preload("res://fonts/ZhiMangXing.ttf")
const SCROLL_TEXTURE := preload("res://assets/opening/scroll_frame_wide.png")

const TITLE_TEXT := "第一关"
const SUBTITLE_TEXT := "雾海哨线 · 雾起"
const SCROLL_ASPECT := 1537.0 / 1022.0
const SCROLL_WIDTH_RATIO := 0.86

var _mask: Control
var _mask_right: ColorRect
var _clip: Control
var _title: Label
var _subtitle: Label
var _hint: Label
var _scroll_width := 0.0
var _scroll_rect := Rect2()
var _finished := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build(get_viewport_rect().size)
	_play()


func _build(view: Vector2) -> void:
	var scroll_width := view.x * SCROLL_WIDTH_RATIO
	var scroll_height := scroll_width / SCROLL_ASPECT
	_scroll_width = scroll_width
	var top := (view.y - scroll_height) * 0.5
	_scroll_rect = Rect2((view.x - scroll_width) * 0.5, top, scroll_width, scroll_height)

	# 卷轴周围的暗场：中间留出卷轴那一块，让地图只从纸窗里透出来。
	_mask = Control.new()
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)

	_add_dark(_mask, Rect2(0.0, 0.0, view.x, _scroll_rect.position.y))
	_add_dark(_mask, Rect2(0.0, _scroll_rect.end.y, view.x, view.y - _scroll_rect.end.y))
	_add_dark(_mask, Rect2(0.0, _scroll_rect.position.y, _scroll_rect.position.x, scroll_height))
	_mask_right = _add_dark(_mask, Rect2(_scroll_rect.position.x, _scroll_rect.position.y, view.x - _scroll_rect.position.x, scroll_height))

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.position = _scroll_rect.position
	_clip.size = Vector2(0.0, scroll_height)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)

	var scroll := TextureRect.new()
	scroll.texture = SCROLL_TEXTURE
	scroll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scroll.stretch_mode = TextureRect.STRETCH_SCALE
	scroll.size = Vector2(scroll_width, scroll_height)
	scroll.position = Vector2.ZERO
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(scroll)

	_title = Label.new()
	_title.text = TITLE_TEXT
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 96)
	_title.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0.0, view.y * 0.34)
	_title.size = Vector2(view.x, 140.0)
	_title.modulate.a = 0.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = SUBTITLE_TEXT
	_subtitle.add_theme_font_override("font", TITLE_FONT)
	_subtitle.add_theme_font_size_override("font_size", 34)
	_subtitle.add_theme_color_override("font_color", Color(0.72, 0.68, 0.6))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = Vector2(0.0, view.y * 0.34 + 130.0)
	_subtitle.size = Vector2(view.x, 50.0)
	_subtitle.modulate.a = 0.0
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)

	_hint = Label.new()
	_hint.text = "点击 / 空格 跳过"
	_hint.add_theme_font_override("font", TITLE_FONT)
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.82, 0.45))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.position = view - Vector2(300.0, 56.0)
	_hint.size = Vector2(260.0, 36.0)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _add_dark(parent: Control, rect: Rect2) -> ColorRect:
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.04, 0.05)
	dark.position = rect.position
	dark.size = rect.size
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dark)
	return dark


func _process(_delta: float) -> void:
	# 暗场的右沿跟着卷轴铺开的进度走，保证地图只从纸窗里露出来。
	if _mask_right != null and _clip != null:
		_mask_right.position.x = _scroll_rect.position.x + _clip.size.x
		_mask_right.size.x = size.x - _mask_right.position.x


func _play() -> void:
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.4)
	tween.tween_interval(0.5)
	# 关卡名先收掉，再让卷轴横向铺开、纸窗露出地图。
	tween.tween_property(_title, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.4)
	tween.tween_property(_clip, "size:x", _scroll_width, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.6)
	tween.tween_property(_mask, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(_clip, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_emit_finished)


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventMouseButton and event.pressed:
		_finish()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var tween := create_tween()
	tween.tween_property(_mask, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_clip, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_hint, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_emit_finished)


func _emit_finished() -> void:
	if _finished and (_clip.modulate.a > 0.0 or _mask.modulate.a > 0.0):
		return
	_finished = true
	finished.emit()
	queue_free()
