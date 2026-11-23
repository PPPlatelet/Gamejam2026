extends CanvasLayer

## 失败页面：基地血量被打空后弹出，暂停游戏，提供「再来一次 / 返回菜单」。
## 由 game.gd 实例化并设置抵达基地的敌人数。

signal retry_requested
signal menu_requested

@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _hint: Label = $Panel/Margin/VBox/Hint
@onready var _stats_label: Label = $Panel/Margin/VBox/Stats
@onready var _retry_button: Button = $Panel/Margin/VBox/Buttons/Retry
@onready var _menu_button: Button = $Panel/Margin/VBox/Buttons/Menu


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


## 显示本局到达基地的敌人数量。
func set_arrived(count: int) -> void:
	_stats_label.text = "共 %d 个敌人抵达基地" % count


## 撑满 15 分钟：把页面切成胜利版。
func set_victory(kills: int) -> void:
	_title.text = "守住了"
	_hint.text = "潮水退去，寨门还立着"
	_stats_label.text = "共击沉 %d 艘敌船" % kills
	_retry_button.text = "再守一次"


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()
