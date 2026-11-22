extends CanvasLayer

## 失败页面：基地血量被打空后弹出，暂停游戏，提供「再来一次 / 返回菜单」。
## 由 game.gd 实例化并设置抵达基地的敌人数。

signal retry_requested
signal menu_requested

@onready var _stats_label: Label = $Panel/Margin/VBox/Stats
@onready var _retry_button: Button = $Panel/Margin/VBox/Buttons/Retry
@onready var _menu_button: Button = $Panel/Margin/VBox/Buttons/Menu


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


## 显示本局到达基地的敌人数量。
func set_arrived(count: int) -> void:
	_stats_label.text = "共 %d 个敌人抵达基地" % count


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()
