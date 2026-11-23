extends Control

## 开始菜单 —— 先做占位版，后面按正式视觉再换。
##
## 现在有：缓慢推镜的背景、标题、三个按钮（开始游戏 / 制作名单 / 退出游戏）。
## 点「开始游戏」淡出到黑，再进入 res://scenes/game.tscn。
## 制作名单目前只弹一行占位提示。

const GAME_SCENE := "res://scenes/game.tscn"
const BACKGROUND := "res://opening/02_shattered_land.png"
const BASE_ZOOM := 1.04

@onready var _bg: TextureRect = %Background
@onready var _curtain: ColorRect = %Curtain
@onready var _start_button: Button = %StartButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _toast: Label = %Toast

var _time := 0.0
var _starting := false
var _toast_time := 0.0


func _ready() -> void:
	_bg.texture = load(BACKGROUND)
	_fit_background()
	resized.connect(_fit_background)

	_curtain.modulate.a = 1.0
	_toast.modulate.a = 0.0
	var open_tween := create_tween()
	open_tween.tween_property(_curtain, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)

	_start_button.pressed.connect(_start_game)
	%DemoButton.pressed.connect(_start_demo)
	_credits_button.pressed.connect(_show_credits)
	_quit_button.pressed.connect(_quit_game)
	_start_button.grab_focus()
	if VN.menu.visible:
		VN.menu.back.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	var zoom := BASE_ZOOM + sin(_time * 0.055) * 0.012
	_bg.scale = Vector2(zoom, zoom)

	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - delta)
		_toast.modulate.a = clampf(_toast_time / 0.35, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if VN.menu.visible or VN.is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_quit_game()


func _fit_background() -> void:
	_bg.pivot_offset = size * 0.5


func _start_game() -> void:
	if _starting:
		return
	_starting = true
	_start_button.disabled = true
	%DemoButton.disabled = true
	_credits_button.disabled = true
	_quit_button.disabled = true
	var fade := create_tween()
	fade.tween_property(_curtain, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	await fade.finished
	get_tree().change_scene_to_file(GAME_SCENE)


func _start_demo() -> void:
	if not _starting:
		VN.show_title()


func _show_credits() -> void:
	_toast.text = "制作名单：占位，正式版再补。"
	_toast_time = 2.2
	_toast.modulate.a = 1.0


func _quit_game() -> void:
	get_tree().quit()
