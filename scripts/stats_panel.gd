extends CanvasLayer

## 按 J 弹出的状态窗口：显示指挥点、粮草、基地血量、敌人、单位、击杀和最近提示。

const ROWS := [
	["command", "指挥点"],
	["supplies", "粮草"],
	["base_hp", "基地血量"],
	["enemies", "场上敌人"],
	["units", "单位"],
	["kills", "击杀"],
	["arrived", "已抵达"],
]

@onready var _grid: GridContainer = $Panel/Margin/VBox/Grid
@onready var _message_label: Label = $Panel/Margin/VBox/Message

var _value_labels := {}


func _ready() -> void:
	for row in ROWS:
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.add_theme_color_override("font_color", Color(0.16, 0.15, 0.13, 0.62))
		name_label.add_theme_font_size_override("font_size", 20)
		_grid.add_child(name_label)

		var value_label := Label.new()
		value_label.text = "-"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.add_theme_color_override("font_color", Color(0.16, 0.15, 0.13, 1))
		value_label.add_theme_font_size_override("font_size", 20)
		_grid.add_child(value_label)
		_value_labels[row[0]] = value_label


func update_values(values: Dictionary) -> void:
	for key in values:
		if _value_labels.has(key):
			_value_labels[key].text = str(values[key])


func set_message(message: String) -> void:
	_message_label.text = message


func toggle() -> void:
	visible = not visible
