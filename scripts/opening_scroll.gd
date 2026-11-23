extends Control

## 开场动画：一幅卷轴从上方慢慢展开，标题像落笔一样写出来，
## 落款、收尾，然后淡出进主菜单。
##
## 时间线：背景 0.6s → 展开 1.9s → 写标题 1.2s → 副标题 0.8s → 停 2s → 淡出 0.9s。
## 左键 / 空格 / 回车 / Esc 可以跳过。

const MENU_SCENE := "res://scenes/main_menu.tscn"
const TITLE_FONT := preload("res://fonts/ZhiMangXing.ttf")
const SCROLL_TEXTURE := preload("res://assets/opening/scroll.png")
const BACKDROP_TEXTURE := preload("res://assets/The_Lands/fog_land.png")

const TITLE_TEXT := "雾海哨线"
const SUBTITLE_TEXT := "潮水退去之前，守住最后一座水寨"
const SCROLL_ASPECT := 1022.0 / 1537.0
const SCROLL_HEIGHT_RATIO := 0.88

var _backdrop: TextureRect
var _clip: Control
var _title: Label
var _subtitle: Label
var _seal: Control
var _hint: Label
var _curtain: ColorRect
var _scroll_height := 0.0
var _finished := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var size_now := get_viewport_rect().size
	_build(size_now)
	_play()


func _build(view: Vector2) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_backdrop = TextureRect.new()
	_backdrop.texture = BACKDROP_TEXTURE
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.modulate = Color(0.55, 0.68, 0.75, 0.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	var scroll_height := view.y * SCROLL_HEIGHT_RATIO
	var scroll_width := scroll_height * SCROLL_ASPECT
	_scroll_height = scroll_height
	var top := (view.y - scroll_height) * 0.5

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.position = Vector2((view.x - scroll_width) * 0.5, top)
	_clip.size = Vector2(scroll_width, 0.0)
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
	_title.add_theme_font_size_override("font_size", int(scroll_width * 0.17))
	_title.add_theme_color_override("font_color", Color(0.15, 0.11, 0.08))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.visible_characters = 0
	_title.position = Vector2(0.0, scroll_height * 0.36)
	_title.size = Vector2(scroll_width, scroll_width * 0.24)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = SUBTITLE_TEXT
	_subtitle.add_theme_font_override("font", TITLE_FONT)
	_subtitle.add_theme_font_size_override("font_size", int(scroll_width * 0.045))
	_subtitle.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.modulate.a = 0.0
	_subtitle.position = Vector2(0.0, scroll_height * 0.56)
	_subtitle.size = Vector2(scroll_width, scroll_width * 0.12)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_subtitle)

	_seal = Control.new()
	_seal.position = Vector2(scroll_width * 0.5 - 26.0, scroll_height * 0.66)
	_seal.size = Vector2(52.0, 52.0)
	_seal.pivot_offset = Vector2(26.0, 26.0)
	_seal.scale = Vector2(0.2, 0.2)
	_seal.rotation = deg_to_rad(6.0)
	_seal.modulate.a = 0.95
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_seal)

	var seal_bg := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.65, 0.2, 0.14)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	seal_bg.add_theme_stylebox_override("panel", style)
	seal_bg.size = Vector2(52.0, 52.0)
	seal_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.add_child(seal_bg)

	var seal_text := Label.new()
	seal_text.text = "守"
	seal_text.add_theme_font_override("font", TITLE_FONT)
	seal_text.add_theme_font_size_override("font_size", 34)
	seal_text.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	seal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal_text.size = Vector2(52.0, 52.0)
	seal_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.add_child(seal_text)

	_hint = Label.new()
	_hint.text = "点击 / 空格 跳过"
	_hint.add_theme_font_override("font", TITLE_FONT)
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.82, 0.45))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = view - Vector2(300.0, 56.0)
	_hint.size = Vector2(260.0, 36.0)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_curtain = ColorRect.new()
	_curtain.color = Color(0.02, 0.02, 0.03)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.modulate.a = 0.0
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)


func _play() -> void:
	var tween := create_tween()
	tween.tween_property(_backdrop, "modulate:a", 0.18, 0.6)
	tween.tween_property(_clip, "size:y", _scroll_height, 1.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title, "visible_characters", TITLE_TEXT.length(), 1.2)
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_property(_seal, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.6)
	tween.tween_property(_curtain, "modulate:a", 1.0, 0.9)
	tween.tween_callback(_goto_menu)


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
	tween.tween_property(_curtain, "modulate:a", 1.0, 0.45)
	tween.tween_callback(_goto_menu)


func _goto_menu() -> void:
	if _finished and _curtain.modulate.a < 1.0:
		return
	_finished = true
	get_tree().change_scene_to_file(MENU_SCENE)
