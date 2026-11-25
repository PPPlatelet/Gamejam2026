extends Control

## 关卡开场：卷轴从左边开始展开——整幅卷轴图从左往右揭开，右侧卷轴辊跟着纸边滚过去；
## 纸窗是透明的，所以只有卷轴打开的部分能看见地图，屏幕其余部分全黑。
##
## 由 game.gd 在开局时套一层 CanvasLayer 实例化，播完发 finished 信号；
## 播放期间游戏主循环不推进（game.gd 里的 _intro_playing），所以 15 分钟从 0 开始算。
## 左键 / 空格 / 回车 / Esc 可以跳过。

signal finished

const SCROLL_TEXTURE := preload("res://assets/opening/scroll_frame_clear.png")
const FX_DROPS := preload("res://assets/fx/drops.png")
const FX_SPLASH := preload("res://assets/fx/splash.png")
const ROLLER_RATIO := 0.095
const OVERLAP := 12.0

const TITLE_TEXT := "第一关"
const SUBTITLE_TEXT := "雾海哨线 · 雾起"

var _title_font: FontVariation
var _mask: Control
var _mask_left: ColorRect
var _mask_right: ColorRect
var _mask_top: ColorRect
var _mask_bottom: ColorRect
var _scroll_clip: Control
var _right_roller: TextureRect
var _title: Label
var _subtitle: Label
var _hint: Label
var _frame_height := 0.0
var _left_mask_width := 0.0
var _frame_width := 0.0
var _roller_width := 0.0
var _unrolling := false
var _fx_timer := 0.0
var _finished := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_font = SongFont.make(500.0)
	_build(get_viewport_rect().size)
	_play()


func _build(view: Vector2) -> void:
	var texture := SCROLL_TEXTURE
	var tex_w := float(texture.get_width())
	var tex_h := float(texture.get_height())
	var roller_tex := tex_w * ROLLER_RATIO

	# 整幅卷轴完整放进屏幕（contain），四周留黑。
	var fit_scale := minf(view.x / tex_w, view.y / tex_h)
	_frame_height = tex_h * fit_scale
	_frame_width = tex_w * fit_scale
	_roller_width = roller_tex * fit_scale
	var x0 := (view.x - _frame_width) * 0.5
	var y0 := (view.y - _frame_height) * 0.5

	# 整幅卷轴：一次性画好，用 clip 从左往右揭开，卷轴本身没有拼接缝。
	_scroll_clip = Control.new()
	_scroll_clip.clip_contents = true
	_scroll_clip.position = Vector2(x0, y0)
	_scroll_clip.size = Vector2(0.0, _frame_height)
	_scroll_clip.modulate.a = 0.0
	_scroll_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll_clip)

	var scroll := TextureRect.new()
	scroll.texture = texture
	scroll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scroll.stretch_mode = TextureRect.STRETCH_SCALE
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(_frame_width, _frame_height)
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_clip.add_child(scroll)

	# 右卷轴辊：跟着纸边滚，盖住裁切边
	var right_tex := AtlasTexture.new()
	right_tex.atlas = texture
	right_tex.region = Rect2(tex_w - roller_tex, 0.0, roller_tex, tex_h)
	_right_roller = TextureRect.new()
	_right_roller.texture = right_tex
	_right_roller.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_roller.stretch_mode = TextureRect.STRETCH_SCALE
	_right_roller.position = Vector2(x0, y0)
	_right_roller.size = Vector2(_roller_width, _frame_height)
	_right_roller.modulate.a = 0.0
	_right_roller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right_roller)

	# 卷轴以外的区域全部压黑
	_mask = Control.new()
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)
	_mask_top = _add_dark(_mask, Rect2(0.0, 0.0, view.x, maxf(0.0, y0)))
	_mask_bottom = _add_dark(_mask, Rect2(0.0, y0 + _frame_height, view.x, maxf(0.0, view.y - y0 - _frame_height)))
	_left_mask_width = maxf(0.0, x0) + 2.0
	_mask_left = _add_dark(_mask, Rect2(0.0, y0, _left_mask_width, _frame_height))
	_mask_right = _add_dark(_mask, Rect2(x0, y0, view.x - x0, _frame_height))

	_title = Label.new()
	_title.text = TITLE_TEXT
	_title.add_theme_font_override("font", _title_font)
	_title.add_theme_font_size_override("font_size", 96)
	_title.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0.0, view.y * 0.34)
	_title.size = Vector2(view.x, 140.0)
	_title.modulate.a = 0.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = SUBTITLE_TEXT
	_subtitle.add_theme_font_override("font", _title_font)
	_subtitle.add_theme_font_size_override("font_size", 34)
	_subtitle.add_theme_color_override("font_color", Color(0.86, 0.84, 0.79))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = Vector2(0.0, view.y * 0.34 + 130.0)
	_subtitle.size = Vector2(view.x, 50.0)
	_subtitle.modulate.a = 0.0
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)

	_hint = Label.new()
	_hint.text = "点击 / 空格 跳过"
	_hint.add_theme_font_override("font", _title_font)
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.83, 0.85, 0.5))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.position = view - Vector2(300.0, 56.0)
	_hint.size = Vector2(260.0, 36.0)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _add_dark(parent: Control, rect: Rect2) -> ColorRect:
	var dark := ColorRect.new()
	dark.color = Color(0.02, 0.025, 0.03)
	dark.position = rect.position
	dark.size = rect.size
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dark)
	return dark


func _process(delta: float) -> void:
	if _scroll_clip == null or _right_roller == null or _mask_right == null:
		return
	# 右辊跟着纸边滚（往左压 12px 盖住裁切边）
	var paper_edge := _scroll_clip.position.x + _scroll_clip.size.x
	_right_roller.position.x = paper_edge - OVERLAP
	_right_roller.size.x = _roller_width + OVERLAP
	# 卷轴右边之外压黑；标题阶段整块卷轴区域一起压黑
	var scroll_right := paper_edge + _roller_width
	# 标题阶段和收尾淡出时，卷轴还没出现/已经消失：整块压黑，左右两侧不要重叠出深色条
	var invisible := _scroll_clip.modulate.a < 0.99
	if invisible:
		scroll_right = 0.0
	_mask_left.size.x = 0.0 if invisible else _left_mask_width
	_mask_right.position.x = scroll_right - 2.0
	_mask_right.size.x = maxf(0.0, size.x - _mask_right.position.x)

	# 展开过程中，右辊边上洒一点墨点，像纸在往外推
	if _unrolling and _scroll_clip.size.x < _frame_width - _roller_width - 2.0:
		_fx_timer -= delta
		if _fx_timer <= 0.0:
			_fx_timer = 0.32
			var at := _right_roller.position + Vector2(_roller_width * 0.5, _frame_height * 0.62)
			Fx.play(self, at, FX_DROPS, 0.32, 0.9, 0.3)


func _play() -> void:
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.35)
	tween.tween_interval(0.35)
	tween.tween_property(_title, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.3)
	# 黑屏上先把卷轴和右辊淡入，再慢慢铺开
	tween.tween_property(_scroll_clip, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(_right_roller, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func() -> void: _unrolling = true)
	tween.tween_property(_scroll_clip, "size:x", _frame_width - _roller_width, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _unrolling = false)
	# 展开完成的一小团墨
	tween.tween_callback(_finish_burst)
	tween.tween_interval(0.45)
	# 先把卷轴淡掉，黑幕保持不透明，最后整块撤掉，不会闪出半透明的地图帧
	tween.tween_property(_scroll_clip, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(_right_roller, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(_hint, "modulate:a", 0.0, 0.2)
	# 卷轴收掉后，黑幕再淡出，露出游戏画面
	tween.tween_property(_mask, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_emit_finished)


## 展开完成时，在右辊位置泼一小团墨，作为收尾。
func _finish_burst() -> void:
	if _finished:
		return
	var at := _right_roller.position + Vector2(_roller_width * 0.5, _frame_height * 0.55)
	Fx.play(self, at, FX_SPLASH, 1.5, 0.45, 0.5)


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
	_unrolling = false
	var tween := create_tween()
	tween.tween_property(_mask, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_scroll_clip, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_right_roller, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_hint, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_emit_finished)


func _emit_finished() -> void:
	if _finished and (_scroll_clip.modulate.a > 0.0 or _mask.modulate.a > 0.0):
		return
	_finished = true
	finished.emit()
	queue_free()
