extends Control

## 游戏开屏：一页一页的全屏插画 + 底部字幕。
##
## 播放顺序：四页插画 → 淡出到黑 → 开始菜单。
## 操作：左键 / 空格 / 回车 继续，Esc 或右上角「跳过开场」直接去菜单。
##
## 想改内容，只改下面的 PAGES：每页一张图、一句字幕、停留时间、缓慢推镜幅度。
## 图片放在 res://opening/ 下，换成你自己的图时保持 16:9 左右最好看。

const MENU_SCENE := "res://scenes/main_menu.tscn"

## 每个字出现需要多少秒（打字符速度）。
const CHAR_SECONDS := 0.045

const PAGES := [
	{
		"image": "res://opening/01_whole_land.png",
		"text": "很久以前，大地是完整的一块。\n河流从山脊流向海，没有一个格子是孤岛。",
		"hold": 1.8,
		"zoom": 1.075,
		"pan": Vector2(-14.0, -8.0),
	},
	{
		"image": "res://opening/02_shattered_land.png",
		"text": "后来它碎了。\n碎成无数六边形的格子，每一格都记得自己原来的位置。",
		"hold": 1.8,
		"zoom": 1.065,
		"pan": Vector2(12.0, 6.0),
	},
	{
		"image": "res://opening/03_red_tide.png",
		"text": "如今，红色的潮水从地图边缘涌来。\n它们沿着格子之间最短的路，一寸一寸逼近。",
		"hold": 1.8,
		"zoom": 1.085,
		"pan": Vector2(0.0, -10.0),
	},
	{
		"image": "res://opening/04_last_light.png",
		"text": "守住左下角的那一点蓝光。\n那是我们最后的家。",
		"hold": 3.0,
		"zoom": 1.07,
		"pan": Vector2(-10.0, 4.0),
	},
]

@onready var _page_a: TextureRect = %PageA
@onready var _page_b: TextureRect = %PageB
@onready var _subtitle: Label = %Subtitle
@onready var _chapter: Label = %Chapter
@onready var _page_label: Label = %PageLabel
@onready var _hint: Label = %Hint
@onready var _skip_button: Button = %SkipButton
@onready var _curtain: ColorRect = %Curtain

var _active_page: TextureRect
var _inactive_page: TextureRect
var _token := 0
var _advance := false
var _leaving := false
var _motion_tween: Tween


func _ready() -> void:
	_fit_pages()
	resized.connect(_fit_pages)
	_skip_button.pressed.connect(_skip_intro)
	_subtitle.text = ""
	_subtitle.modulate.a = 1.0
	_chapter.modulate.a = 0.0
	_page_label.modulate.a = 0.0
	_hint.modulate.a = 0.0
	_skip_button.modulate.a = 0.0
	_curtain.modulate.a = 1.0
	_play()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_skip_intro()
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_advance = true
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_advance = true


# ---------------------------------------------------------------- 播放流程

func _play() -> void:
	var token := _token
	_prepare_page(_page_a, 0)
	_page_b.modulate.a = 0.0
	_active_page = _page_a
	_inactive_page = _page_b
	_page_label.text = "01 / %02d" % PAGES.size()
	_start_motion(_page_a, 0)

	var open_tween := create_tween().set_parallel(true)
	open_tween.tween_property(_curtain, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	open_tween.tween_property(_chapter, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	open_tween.tween_property(_page_label, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	open_tween.tween_property(_hint, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	open_tween.tween_property(_skip_button, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)

	await _wait_seconds(0.55, token)
	if token != _token:
		return

	for index in PAGES.size():
		if index > 0:
			await _switch_page(index, token)
			if token != _token:
				return
		await _play_text(index, token)
		if token != _token:
			return

	_leave_to_menu()


func _switch_page(index: int, token: int) -> void:
	var fade_out := create_tween()
	fade_out.tween_property(_subtitle, "modulate:a", 0.0, 0.28)
	await fade_out.finished
	if token != _token:
		return

	var old_page := _active_page
	var new_page := _inactive_page
	_prepare_page(new_page, index, 0.0)
	new_page.scale = Vector2(1.015, 1.015)

	_page_label.text = "%02d / %02d" % [index + 1, PAGES.size()]

	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.tween_property(new_page, "modulate:a", 1.0, 1.05).set_trans(Tween.TRANS_SINE)
	_motion_tween.tween_property(old_page, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	_motion_tween.tween_property(new_page, "scale", Vector2.ONE * float(PAGES[index].zoom), _page_seconds(index)).set_trans(Tween.TRANS_SINE)
	_motion_tween.tween_property(new_page, "position", PAGES[index].pan, _page_seconds(index)).set_trans(Tween.TRANS_SINE)

	_active_page = new_page
	_inactive_page = old_page
	await _wait_seconds(0.95, token)
	if token != _token:
		return
	_subtitle.modulate.a = 1.0


func _play_text(index: int, token: int) -> void:
	var page: Dictionary = PAGES[index]
	_subtitle.text = str(page.text)
	_subtitle.visible_characters = 0
	_subtitle.modulate.a = 1.0

	var total := float(_subtitle.get_total_character_count())
	var shown := 0.0
	while shown < total:
		await get_tree().process_frame
		if token != _token:
			return
		if _advance:
			_advance = false
			break
		shown += get_process_delta_time() / CHAR_SECONDS
		_subtitle.visible_characters = mini(int(shown), int(total))
	_subtitle.visible_characters = -1

	await _wait_seconds(float(page.hold), token)


func _wait_seconds(seconds: float, token: int) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		if token != _token:
			return
		if _advance:
			_advance = false
			return
		elapsed += get_process_delta_time()


# ---------------------------------------------------------------- 页面与转场

func _prepare_page(page: TextureRect, index: int, alpha := 1.0) -> void:
	page.texture = load(str(PAGES[index].image))
	page.modulate = Color(1.0, 1.0, 1.0, alpha)
	page.scale = Vector2.ONE
	page.position = Vector2.ZERO


func _start_motion(page: TextureRect, index: int) -> void:
	var data: Dictionary = PAGES[index]
	var duration := _page_seconds(index)
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.tween_property(page, "scale", Vector2.ONE * float(data.zoom), duration).set_trans(Tween.TRANS_SINE)
	_motion_tween.tween_property(page, "position", data.pan, duration).set_trans(Tween.TRANS_SINE)


func _page_seconds(index: int) -> float:
	var text_length := str(PAGES[index].text).length()
	return 1.1 + float(text_length) * CHAR_SECONDS + float(PAGES[index].hold) + 0.6


func _fit_pages() -> void:
	var half := size * 0.5
	_page_a.pivot_offset = half
	_page_b.pivot_offset = half


func _skip_intro() -> void:
	if _leaving:
		return
	_leave_to_menu()


func _leave_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_token += 1
	_skip_button.disabled = true
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()

	var fade := create_tween().set_parallel(true)
	fade.tween_property(_subtitle, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	fade.tween_property(_chapter, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	fade.tween_property(_hint, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	fade.tween_property(_page_label, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	fade.tween_property(_skip_button, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	await fade.finished

	var black := create_tween()
	black.tween_property(_curtain, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	await black.finished
	get_tree().change_scene_to_file(MENU_SCENE)
