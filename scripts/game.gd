extends Node2D

## 六边形塔防 · 框架
##
## 地图：左下角是基地，上边和右边是敌人的出生点；敌人沿最短路径一格一格走过来。
## 障碍物和塔都会占住格子，敌人会自动绕道（绕道后依旧是最短路径）。
##
## 屏幕适配：棋盘按窗口大小自动决定列数 / 行数，再整体缩放铺满窗口；
## 改窗口大小、换分辨率、全屏都只用同一套逻辑坐标。

const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")
const UNIT_SCENE := preload("res://scenes/entities/unit.tscn")
const UnitClass := preload("res://scripts/unit.gd")
const OBSTACLE_SCENE := preload("res://scenes/entities/obstacle.tscn")
const BASE_SCENE := preload("res://scenes/entities/base.tscn")

## 第一关的剧情文件；换关卡时改这里，或者直接调 VN.open_file("res://vn/xxx.json")。
const VN_STORY_PATH := "res://vn/first_level.json"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_OVER_SCENE := preload("res://scenes/game_over.tscn")
const STATS_PANEL_SCENE := preload("res://scenes/stats_panel.tscn")

const HexBoardClass := preload("res://scripts/hex_board.gd")
const StoryLines := preload("res://scripts/story_lines.gd")
const STORY_OVERLAY_SCENE := preload("res://scenes/story_overlay.tscn")

@export_group("屏幕适配")
## 打开后按窗口大小自动算格子数；关掉就用下面两个固定值。
@export var auto_fit_screen := true
## 每格的目标半径（逻辑像素），越小格子越多。
@export var target_hex_radius := 60.0
@export var fixed_columns := 17
@export var fixed_rows := 10
## 棋盘四周留白占短边的比例。
@export var margin_ratio := 0.03
## 顶部预留高度（没有顶部 UI 时保持 0，棋盘就能铺满全屏）。
@export var hud_height := 0.0

@export_group("玩法")
## 基地血量：每有一个敌人抵达就扣 1，扣到 0 弹出失败页面。
@export var base_max_hp := 20
## 每个敌人的血量；船的数值见 scripts/unit.gd。
@export var enemy_max_hp := 40.0
@export var obstacle_count := 7
@export var enemy_speed_cells := 1.0
@export var level_seed := 20261122

@export_group("格子")
## 直接删掉的格子编号区间，编号沿用旧的「行 × 列数 + 列 + 1」行优先编号。
@export var removed_cell_ranges := [[1, 60], [74, 77], [91, 92], [109, 111], [127, 127]]
## 删完之后再补回来的格子（列, 行，从 0 开始）。
## 当前补的是 I4~R4 上面一行（I3~R3）+ A9 上方一格（A8）+ B8 上方一格（B7）。
@export var restored_cells: Array[Vector2i] = [
	Vector2i(8, 2), Vector2i(9, 2), Vector2i(10, 2), Vector2i(11, 2), Vector2i(12, 2),
	Vector2i(13, 2), Vector2i(14, 2), Vector2i(15, 2), Vector2i(16, 2), Vector2i(17, 2),
	Vector2i(0, 7), Vector2i(1, 6),
]

@export_group("操作")
## 关着是「点塔选中 → 点格子移动」；打开是拖动移动（给以后的新功能留的）。
@export var drag_to_move := false

@export_group("资源")
## 开局给的资源（设成 0 就是从零开始攒）。
@export var start_command := 10.0
@export var start_supplies := 40.0
## 指挥点：每秒 +command_per_second，最多 command_max。
@export var command_max := 50.0
@export var command_per_second := 1.0
## 粮草：每 supplies_seconds 秒 +1，最多 supplies_max。
@export var supplies_max := 200.0
@export var supplies_seconds := 5.0
## 移动每走一格扣指挥点。
@export var move_cost_per_cell := 2.0

@onready var _board_view = $BoardView
@onready var _place_buttons_box: VBoxContainer = $PlaceUI/Buttons

var board: HexBoardClass
var _enemies: Array = []
var _unit_nodes: Dictionary = {}
var _reached := 0
var _kills := 0
var _base_hp := 20
var _is_over := false
var _command := 0.0
var _supplies := 0.0
var _selected_unit_cell := Vector2i(-1, -1)
var _drag_candidate_tower = null
var _drag_candidate_cell := Vector2i(-1, -1)
var _drag_start_local := Vector2.ZERO
var _dragging := false
var _drag_tower = null
var _drag_from_cell := Vector2i(-1, -1)
var _drag_grab_offset := Vector2.ZERO
var _drag_target_valid := true
var _stats_panel
var _placing := false
var _place_type := -1
var _place_drag_held := false
var _ghost_unit = null
var _place_buttons := {}
var _active_place_button = null
var _last_message := ""
var _j_held := false
var _j_used_for_spawn := false
var _rng := RandomNumberGenerator.new()
var _spawn_paths: Array = []
var _story_overlay
var _story_fired := {}
var _spawned_total := 0
var _units_lost := 0
var _elapsed := 0.0


func _ready() -> void:
	_base_hp = base_max_hp
	_command = start_command
	_supplies = start_supplies
	_rng.seed = level_seed
	_build_board()
	_remove_cells()
	_restore_cells()
	_relocate_spawns()
	_board_view.board = board
	_fit_board()
	_add_base_marker()
	_add_obstacles()
	_refresh_paths()
	_stats_panel = STATS_PANEL_SCENE.instantiate()
	add_child(_stats_panel)
	_stats_panel.hide()
	get_viewport().size_changed.connect(_fit_board)
	_build_unit_buttons()
	_story_overlay = STORY_OVERLAY_SCENE.instantiate()
	add_child(_story_overlay)
	_story_overlay = _story_overlay.get_node("Caption")
	_toast("按住左边按钮放船；按 L 出怪")

	# 想让第一关一开局就自动播剧情，取消下面这行的注释即可：
	# VN.open_file(VN_STORY_PATH)


func _process(delta: float) -> void:
	if board == null or _is_over:
		return

	_command = minf(command_max, _command + command_per_second * delta)
	_supplies = minf(supplies_max, _supplies + delta / maxf(supplies_seconds, 0.01))
	_elapsed += delta
	_check_story()
	_refresh_panel()

	if _placing:
		_update_ghost()
		# 按住左边按钮拖出来的船，松手就放下
		if _place_drag_held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_place_drag_held = false
			if not _point_over_unit_buttons():
				_try_place(_mouse_cell())
	else:
		for type in _place_buttons:
			_place_buttons[type].disabled = _supplies < UnitClass.STATS[type].cost


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _placing:
			_update_ghost()
		elif drag_to_move and (_dragging or _drag_candidate_tower != null):
			if _dragging:
				_update_drag()
			else:
				var mouse_local: Vector2 = _board_view.to_local(get_global_mouse_position())
				if mouse_local.distance_to(_drag_start_local) > 0.12:
					_start_drag()
					_update_drag()
		else:
			_update_hover()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _placing:
				if event.pressed:
					_try_place(_mouse_cell())
			elif drag_to_move:
				if event.pressed:
					_on_left_pressed(_mouse_cell())
				else:
					_on_left_released()
			elif event.pressed:
				_handle_left_click(_mouse_cell())
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _placing:
				_cancel_place_mode()
			elif drag_to_move and _dragging:
				_cancel_drag()
	elif event is InputEventKey and not event.echo:
		# J 按住不放时按 1~4 出指定的敌人；只按 J 则开关状态窗口。
		if event.keycode == KEY_J:
			if event.pressed:
				_j_held = true
				_j_used_for_spawn = false
			else:
				_j_held = false
				if not _j_used_for_spawn:
					_stats_panel.toggle()
					if _stats_panel.visible:
						_refresh_panel()
				_j_used_for_spawn = false
			return
		if not event.pressed:
			return
		if _j_held:
			var enemy_kind := -1
			match event.keycode:
				KEY_1, KEY_KP_1:
					enemy_kind = 0
				KEY_2, KEY_KP_2:
					enemy_kind = 1
				KEY_3, KEY_KP_3:
					enemy_kind = 2
				KEY_4, KEY_KP_4:
					enemy_kind = 3
			if enemy_kind >= 0:
				_j_used_for_spawn = true
				_spawn_enemy(enemy_kind)
				return
		match event.keycode:
			KEY_P:
				_board_view.show_paths = not _board_view.show_paths
				_board_view.queue_redraw()
				_toast("路线显示：" + ("开" if _board_view.show_paths else "关"))
			KEY_H:
				_board_view.show_numbers = not _board_view.show_numbers
				_board_view.queue_redraw()
				_toast("格子编号：" + ("开" if _board_view.show_numbers else "关"))
			KEY_V:
				_open_vn()
			KEY_L:
				_spawn_enemy()
			KEY_R:
				get_tree().reload_current_scene()
			KEY_F11:
				_toggle_fullscreen()
			KEY_ESCAPE:
				if _placing:
					_cancel_place_mode()
				elif _stats_panel.visible:
					_stats_panel.hide()
				else:
					get_tree().change_scene_to_file(MENU_SCENE)


# ---------------------------------------------------------------- 地图

func _build_board() -> void:
	var columns := fixed_columns
	var rows := fixed_rows
	if auto_fit_screen:
		var area := _play_area().size
		var cell_width := HexBoardClass.HEX_WIDTH * target_hex_radius
		var cell_height := HexBoardClass.ROW_STEP * target_hex_radius
		columns = maxi(6, floori(area.x / cell_width))
		rows = maxi(5, floori((area.y - 2.0 * target_hex_radius) / cell_height) + 1)

	board = HexBoardClass.new(columns, rows)
	board.base_cell = Vector2i(0, rows - 1)

	# 上边三个出生点 + 右边三个出生点
	for i in 3:
		var column := roundi((columns - 1) * (0.25 + 0.25 * i))
		_add_spawn(Vector2i(column, 0))
	for i in 3:
		var row := roundi((rows - 1) * (0.25 + 0.25 * i))
		_add_spawn(Vector2i(columns - 1, row))


func _add_spawn(cell: Vector2i) -> void:
	if board.is_inside(cell) and cell != board.base_cell and not board.spawn_cells.has(cell):
		board.spawn_cells.append(cell)


func _play_area() -> Rect2:
	var viewport_size := get_viewport_rect().size
	return Rect2(0.0, hud_height, viewport_size.x, viewport_size.y - hud_height)


func _fit_board() -> void:
	if board == null or _board_view == null:
		return
	var area := _play_area()
	var board_size := board.bounds().size
	var usable := area.size * (1.0 - margin_ratio * 2.0)
	var scale_factor := minf(usable.x / board_size.x, usable.y / board_size.y)
	_board_view.scale = Vector2(scale_factor, scale_factor)
	_board_view.position = area.get_center()
	_board_view.queue_redraw()


# ---------------------------------------------------------------- 场景内容

func _add_base_marker() -> void:
	var marker: Node2D = BASE_SCENE.instantiate()
	marker.position = board.cell_center(board.base_cell)
	_board_view.add_child(marker)


func _add_obstacles() -> void:
	var candidates := board.all_cells()
	_shuffle(candidates)
	var placed := 0
	for cell in candidates:
		if placed >= obstacle_count:
			break
		if cell == board.base_cell or board.spawn_cells.has(cell):
			continue
		if cell.y == 0 or cell.x == board.columns - 1:
			continue   # 出生点所在的行 / 列不放障碍物
		if board.is_blocked(cell) or not _can_block(cell):
			continue
		board.block(cell, "obstacle")
		var obstacle: Node2D = OBSTACLE_SCENE.instantiate()
		obstacle.position = board.cell_center(cell)
		_board_view.add_child(obstacle)
		placed += 1


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp


# ---------------------------------------------------------------- 放置 / 拆除

## 直接删掉一部分格子：这些格子不参与寻路、放船、悬停和编号。
func _remove_cells() -> void:
	var total := board.columns * board.rows
	for pair in removed_cell_ranges:
		for number in range(int(pair[0]), int(pair[1]) + 1):
			var index: int = number - 1
			if index < 0 or index >= total:
				continue
			board.remove_cell(Vector2i(index % board.columns, index / board.columns))


## 删除之后再把一部分格子补回来。
func _restore_cells() -> void:
	for cell in restored_cells:
		board.restore_cell(cell)


## 出生点如果正好被删掉，就沿该列往下 / 该行往左找最近的可用格。
func _relocate_spawns() -> void:
	var fixed: Array[Vector2i] = []
	for spawn in board.spawn_cells:
		if not board.is_removed(spawn):
			fixed.append(spawn)
			continue
		var replacement := _nearest_open_cell(spawn)
		if replacement != Vector2i(-1, -1) and not fixed.has(replacement):
			fixed.append(replacement)
	board.spawn_cells = fixed


func _nearest_open_cell(from: Vector2i) -> Vector2i:
	for step in board.rows:
		var down := Vector2i(from.x, from.y + step)
		if board.is_inside(down) and not board.is_removed(down) and down != board.base_cell:
			return down
	for step in board.columns:
		var left := Vector2i(from.x - step, from.y)
		if board.is_inside(left) and not board.is_removed(left) and left != board.base_cell:
			return left
	return Vector2i(-1, -1)


func _try_build(cell: Vector2i, type := 0, from_base := false) -> bool:
	if board == null or not board.is_inside(cell):
		return false
	if board.is_removed(cell):
		_toast("这一格不存在")
		return false
	if cell == board.base_cell or board.spawn_cells.has(cell):
		_toast("基地和出生点不能放")
		return false
	if board.is_blocked(cell):
		_toast("这个格子已经有东西了")
		return false
	if _enemy_near(cell):
		_toast("敌人正从这里经过")
		return false
	if not _can_block(cell):
		_toast("这里放会把敌人的路彻底堵死")
		return false
	var stats: Dictionary = UnitClass.STATS[type]
	if _supplies < stats.cost:
		_toast("粮草不足：%s 需要 %d" % [stats.name, int(stats.cost)])
		return false

	_supplies -= stats.cost
	board.block(cell, "unit")
	var unit = UNIT_SCENE.instantiate()
	unit.setup(type)
	unit.died.connect(_on_unit_died)
	_unit_nodes[cell] = unit
	_board_view.add_child(unit)

	if from_base:
		# 新船从基地出发，滑到目标格；途中不开火、不转向。
		unit.position = board.cell_center(board.base_cell)
		var distance := board.hex_distance(board.base_cell, cell)
		unit.move_to(board.cell_center(cell), clampf(0.30 * distance, 0.25, 2.5))
		_show_move_marker(cell, unit)
	else:
		unit.position = board.cell_center(cell)

	_repath_enemies()
	_refresh_paths()
	_update_stats()
	_update_resources()
	return true


## 单位被打掉：清掉占格、重新寻路。
func _on_unit_died(unit) -> void:
	var cell := Vector2i(-1, -1)
	for key in _unit_nodes:
		if _unit_nodes[key] == unit:
			cell = key
			break
	if cell == Vector2i(-1, -1):
		return
	_unit_nodes.erase(cell)
	board.unblock(cell)
	if _selected_unit_cell == cell:
		_select_tower(Vector2i(-1, -1))
	_repath_enemies()
	_refresh_paths()
	_update_stats()
	_update_resources()
	_units_lost += 1
	var unit_name: String = unit.stats.name if unit != null and is_instance_valid(unit) else "单位"
	_toast("%s 被摧毁了" % unit_name)


# ---------------------------------------------------------------- 点选移动

## 左键：点塔选中，再点空格移动；点空格放塔。
func _handle_left_click(cell: Vector2i) -> void:
	if _selected_unit_cell != Vector2i(-1, -1):
		if cell == _selected_unit_cell:
			_select_tower(Vector2i(-1, -1))
		elif _unit_nodes.has(cell):
			_select_tower(cell)
		else:
			if _try_move_unit(_selected_unit_cell, cell):
				_select_tower(Vector2i(-1, -1))
		return

	if _unit_nodes.has(cell):
		_select_tower(cell)


func _select_tower(cell: Vector2i) -> void:
	_selected_unit_cell = cell
	_board_view.selected_cell = cell
	_board_view.queue_redraw()


# ---------------------------------------------------------------- 放船按钮

const TYPE_SENTRY := 0
const TYPE_ROCKET := 1
const TYPE_CANNON := 2


## 左边三个按钮，按住其中一个拖动就是放对应的船。
func _build_unit_buttons() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC",
	])
	for type in [TYPE_SENTRY, TYPE_ROCKET, TYPE_CANNON]:
		var stats: Dictionary = UnitClass.STATS[type]
		var color: Color = stats.color
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(210, 54)
		button.text = "%s · %d粮草" % [stats.name, int(stats.cost)]
		button.tooltip_text = "%s\n%s\n血量 %d · 花费 %d 粮草" % [
			stats.name, stats.desc, int(stats.hp), int(stats.cost)
		]
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color(0.92, 0.94, 1.0))
		button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.65))
		button.add_theme_stylebox_override("normal", _make_button_style(color))
		button.add_theme_stylebox_override("hover", _make_button_style(color.lightened(0.12)))
		button.add_theme_stylebox_override("pressed", _make_button_style(color.darkened(0.15)))
		button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.62, 0.66, 0.72, 0.55)))
		button.button_down.connect(_on_unit_button_down.bind(type))
		button.pressed.connect(_on_unit_button_pressed.bind(type))
		_place_buttons_box.add_child(button)
		_place_buttons[type] = button


func _make_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0.06, 0.18, 0.55, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


func _on_unit_button_down(type: int) -> void:
	if _placing:
		return
	_enter_place_mode(type)


func _on_unit_button_pressed(type: int) -> void:
	# 松开时还停在按钮上：刚按下去那一下保持放船模式等玩家拖；
	# 已经处于放船模式再点按钮，则取消。
	if _placing and not _place_drag_held:
		_cancel_place_mode()


func _enter_place_mode(type: int) -> void:
	if _is_over or _placing:
		return
	var stats: Dictionary = UnitClass.STATS[type]
	if _supplies < stats.cost:
		_toast("粮草不足：%s 需要 %d" % [stats.name, int(stats.cost)])
		return

	_placing = true
	_place_type = type
	_place_drag_held = true
	_select_tower(Vector2i(-1, -1))
	_ghost_unit = UNIT_SCENE.instantiate()
	_ghost_unit.setup(type)
	_ghost_unit.modulate = Color(1, 1, 1, 0.65)
	_board_view.add_child(_ghost_unit)
	# 必须在进树之后再关，否则会被 _process 自动开启。
	_ghost_unit.set_process(false)
	_board_view.show_grid = true

	_active_place_button = _place_buttons.get(type)
	if _active_place_button != null:
		_active_place_button.text = "拖到格子上"
		_active_place_button.disabled = false
	for other_type in _place_buttons:
		if other_type != type:
			_place_buttons[other_type].disabled = true
	_update_ghost()
	_toast("把%s拖到格子上，松手放下" % stats.name)


func _cancel_place_mode() -> void:
	if not _placing:
		return
	_placing = false
	_place_drag_held = false
	if _ghost_unit != null and is_instance_valid(_ghost_unit):
		_ghost_unit.queue_free()
	_ghost_unit = null
	_board_view.show_grid = false
	_board_view.hover_cell = Vector2i(-1, -1)
	_board_view.drag_cell = Vector2i(-1, -1)
	_board_view.drag_target_cell = Vector2i(-1, -1)
	_board_view.queue_redraw()
	for type in _place_buttons:
		var stats: Dictionary = UnitClass.STATS[type]
		_place_buttons[type].text = "%s · %d粮草" % [stats.name, int(stats.cost)]
		_place_buttons[type].disabled = _supplies < stats.cost
	_active_place_button = null
	_place_type = -1


func _update_ghost() -> void:
	_apply_ghost(_board_view.to_local(get_global_mouse_position()))


## 用给定的棋盘本地坐标更新虚影（方便测试）。
func _apply_ghost(mouse_local: Vector2) -> void:
	if _ghost_unit == null or not is_instance_valid(_ghost_unit):
		return
	var cell := board.world_to_cell(mouse_local)
	var cost: float = UnitClass.STATS[_place_type].cost if _place_type >= 0 else 0.0
	if board.is_inside(cell) and not board.is_removed(cell):
		_ghost_unit.position = board.cell_center(cell)
		_board_view.hover_cell = cell
		var valid := _can_place(cell) and _supplies >= cost
		_board_view.hover_valid = valid
		_board_view.drag_cell = cell
		_board_view.drag_target_cell = cell
		_board_view.drag_target_valid = valid
		_ghost_unit.modulate = Color(1.0, 0.55, 0.55, 0.65) if not valid else Color(1, 1, 1, 0.65)
	else:
		_ghost_unit.position = mouse_local
		_board_view.hover_cell = Vector2i(-1, -1)
		_board_view.drag_cell = Vector2i(-1, -1)
		_board_view.drag_target_cell = Vector2i(-1, -1)
	_board_view.queue_redraw()


func _try_place(cell: Vector2i) -> void:
	if board == null or not board.is_inside(cell) or _place_type < 0:
		return
	var stats: Dictionary = UnitClass.STATS[_place_type]
	if _supplies < stats.cost:
		_toast("粮草不足：%s 需要 %d" % [stats.name, int(stats.cost)])
		return
	if not _can_place(cell):
		_toast("这里不能放")
		return
	var type := _place_type
	_cancel_place_mode()
	_try_build(cell, type, true)


func _point_over_unit_buttons() -> bool:
	for button in _place_buttons.values():
		if button.get_rect().has_point(button.get_local_mouse_position()):
			return true
	return false


# ---------------------------------------------------------------- 拖拽移动

func _on_left_pressed(cell: Vector2i) -> void:
	if _unit_nodes.has(cell):
		var tower = _unit_nodes[cell]
		if tower.is_moving():
			_toast("塔正在移动")
			return
		_drag_candidate_tower = tower
		_drag_candidate_cell = cell
		_drag_start_local = _board_view.to_local(get_global_mouse_position())
	else:
		_try_build(cell)


func _on_left_released() -> void:
	if _dragging:
		_finish_drag()
	_drag_candidate_tower = null
	_drag_candidate_cell = Vector2i(-1, -1)


func _start_drag() -> void:
	_dragging = true
	_drag_tower = _drag_candidate_tower
	_drag_from_cell = _drag_candidate_cell
	var mouse_local: Vector2 = _board_view.to_local(get_global_mouse_position())
	_drag_grab_offset = _drag_tower.position - mouse_local
	_drag_tower.set_held(true)
	_board_view.hover_cell = Vector2i(-1, -1)
	_board_view.show_grid = true
	_board_view.queue_redraw()


func _update_drag() -> void:
	_apply_drag(_board_view.to_local(get_global_mouse_position()))


## 用给定的鼠标位置（棋盘本地坐标）更新拖拽状态，方便测试。
func _apply_drag(mouse_local: Vector2) -> void:
	if _drag_tower == null or not is_instance_valid(_drag_tower):
		_end_drag_visuals()
		return
	var target_position := _clamp_to_board(mouse_local + _drag_grab_offset)
	_drag_tower.position = target_position

	var under_cell := board.world_to_cell(target_position)
	_board_view.drag_cell = under_cell if board.is_inside(under_cell) else Vector2i(-1, -1)

	var target_cell := board.world_to_cell(mouse_local)
	if not board.is_inside(target_cell):
		target_cell = Vector2i(-1, -1)
	if target_cell != _board_view.drag_target_cell:
		_board_view.drag_target_cell = target_cell
		_drag_target_valid = _can_drop(_drag_from_cell, target_cell)
	_board_view.drag_target_valid = _drag_target_valid
	_board_view.queue_redraw()


func _finish_drag() -> void:
	var tower = _drag_tower
	var from_cell := _drag_from_cell
	var target_cell: Vector2i = _board_view.drag_target_cell
	var valid := _drag_target_valid
	_end_drag_visuals()
	if tower == null or not is_instance_valid(tower):
		return
	tower.set_held(false)
	if valid and target_cell != from_cell and board.is_inside(target_cell):
		if _try_move_unit(from_cell, target_cell):
			return
	tower.move_to(board.cell_center(from_cell), 0.18)


func _cancel_drag() -> void:
	var tower = _drag_tower
	var from_cell := _drag_from_cell
	_end_drag_visuals()
	if tower != null and is_instance_valid(tower):
		tower.set_held(false)
		tower.move_to(board.cell_center(from_cell), 0.18)


func _end_drag_visuals() -> void:
	_dragging = false
	_drag_tower = null
	_drag_candidate_tower = null
	_drag_candidate_cell = Vector2i(-1, -1)
	_board_view.show_grid = false
	_board_view.drag_cell = Vector2i(-1, -1)
	_board_view.drag_target_cell = Vector2i(-1, -1)
	_board_view.queue_redraw()


func _clamp_to_board(point: Vector2) -> Vector2:
	var half := board.bounds().size * 0.5
	return Vector2(
		clampf(point.x, -half.x + 0.6, half.x - 0.6),
		clampf(point.y, -half.y + 0.6, half.y - 0.6)
	)


## 松手时这一格能不能放：空格、不堵路、指挥点够。
func _can_drop(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if to_cell == Vector2i(-1, -1):
		return false
	if to_cell == from_cell:
		return true
	if not board.is_inside(to_cell):
		return false
	if board.is_removed(to_cell):
		return false
	if to_cell == board.base_cell or board.spawn_cells.has(to_cell):
		return false
	if board.is_blocked(to_cell):
		return false
	if _enemy_near(to_cell):
		return false
	var distance := board.hex_distance(from_cell, to_cell)
	if _command < distance * move_cost_per_cell:
		return false
	return _can_move_unit(from_cell, to_cell)


## 把塔从 from_cell 移到 to_cell，按格子距离扣指挥点。成功返回 true。
func _try_move_unit(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if board == null or not board.is_inside(to_cell):
		return false
	if board.is_removed(to_cell):
		_toast("这一格不开放")
		return false
	if to_cell == board.base_cell or board.spawn_cells.has(to_cell):
		_toast("基地和出生点不能放塔")
		return false
	if board.is_blocked(to_cell):
		_toast("目标格已经有东西了")
		return false
	if _enemy_near(to_cell):
		_toast("敌人正从这里经过")
		return false

	var tower = _unit_nodes.get(from_cell)
	if tower == null or not is_instance_valid(tower):
		return false
	if tower.is_moving():
		_toast("塔正在移动")
		return false

	var distance := board.hex_distance(from_cell, to_cell)
	var cost := distance * move_cost_per_cell
	if _command < cost:
		_toast("指挥点不足：移动 %d 格需要 %d" % [distance, int(cost)])
		return false
	if not _can_move_unit(from_cell, to_cell):
		_toast("移过去会把敌人的路堵死")
		return false

	board.unblock(from_cell)
	board.block(to_cell, "tower")
	_unit_nodes.erase(from_cell)
	_unit_nodes[to_cell] = tower

	var duration := clampf(0.30 * distance, 0.25, 2.5)
	tower.move_to(board.cell_center(to_cell), duration)
	_show_move_marker(to_cell, tower)

	_command -= cost
	_repath_enemies()
	_refresh_paths()
	_update_stats()
	_update_resources()
	return true


## 滑行期间在目的地显示带刻度的蓝框，落地后清掉。
func _show_move_marker(cell: Vector2i, tower) -> void:
	_board_view.drag_target_cell = cell
	_board_view.drag_target_valid = true
	_board_view.queue_redraw()
	tower.move_finished.connect(_on_tower_move_finished.bind(cell), CONNECT_ONE_SHOT)


func _on_tower_move_finished(target_cell: Vector2i) -> void:
	if _board_view.drag_target_cell == target_cell:
		_board_view.drag_target_cell = Vector2i(-1, -1)
		_board_view.queue_redraw()


## 假设塔从 from_cell 挪到 to_cell，检查所有出生点是否还走得到基地。
func _can_move_unit(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	board.unblock(from_cell)
	board.block(to_cell, "check")
	var reachable := true
	for spawn in board.spawn_cells:
		if board.find_path(spawn, board.base_cell).is_empty():
			reachable = false
			break
	board.unblock(to_cell)
	board.block(from_cell, "tower")
	return reachable


## 假设这一格被挡住，检查所有出生点是否都还能走到基地。
func _can_block(cell: Vector2i) -> bool:
	if cell == board.base_cell or board.spawn_cells.has(cell):
		return false
	if board.is_blocked(cell):
		return false
	board.block(cell, "check")
	var reachable := true
	for spawn in board.spawn_cells:
		if board.find_path(spawn, board.base_cell).is_empty():
			reachable = false
			break
	board.unblock(cell)
	return reachable


func _can_place(cell: Vector2i) -> bool:
	if not board.is_inside(cell):
		return false
	if board.is_removed(cell):
		return false
	if board.is_blocked(cell):
		return false
	if _enemy_near(cell):
		return false
	return _can_block(cell)


func _enemy_near(cell: Vector2i) -> bool:
	var center := board.cell_center(cell)
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.position.distance_to(center) < 0.75:
			return true
	return false


# ---------------------------------------------------------------- 剧情文案

## 每帧检查剧本里还没播过的条目，满足条件就交给字幕层。
func _check_story() -> void:
	if _story_overlay == null:
		return
	for line in StoryLines.LINES:
		var id := str(line.get("id", ""))
		if id.is_empty():
			continue
		var once: bool = line.get("once", true)
		if _story_fired.has(id):
			if once:
				continue
			var cooldown: float = line.get("cooldown", 20.0)
			if _elapsed - float(_story_fired[id]) < cooldown:
				continue
		if _story_condition(line.get("when", {})):
			_story_fired[id] = _elapsed
			_story_overlay.show_line(
				str(line.get("text", "")),
				str(line.get("where", "bottom")),
				float(line.get("seconds", 5.0))
			)


func _story_condition(when: Dictionary) -> bool:
	if when.is_empty():
		return false
	match str(when.get("type", "")):
		"start":
			return true
		"time":
			return _elapsed >= float(when.get("seconds", 0.0))
		"spawn":
			return _spawned_total >= int(when.get("count", 1))
		"kills":
			return _kills >= int(when.get("count", 1))
		"reached":
			return _reached >= int(when.get("count", 1))
		"base_hp":
			return _base_hp <= int(when.get("below", 10))
		"units":
			return _unit_nodes.size() >= int(when.get("count", 1))
		"supplies":
			return _supplies >= float(when.get("count", 0.0))
		"unit_died":
			return _units_lost >= int(when.get("count", 1))
		"game_over":
			return _is_over
	return false


# ---------------------------------------------------------------- 敌人

func _spawn_enemy(type := -1) -> void:
	if board.spawn_cells.is_empty():
		return
	if type < 0:
		type = _random_enemy_type()
	var spawn: Vector2i = board.spawn_cells[_rng.randi_range(0, board.spawn_cells.size() - 1)]
	var waypoint := Vector2i(-1, -1)
	if _rng.randf() < 0.45:
		waypoint = _pick_waypoint(spawn)
	var cells := _route_through(spawn, waypoint)
	if cells.size() < 2:
		return
	var points := PackedVector2Array()
	for cell in cells:
		points.append(board.cell_center(cell))
	var enemy = ENEMY_SCENE.instantiate()
	enemy.configure(type)
	enemy.reached_base.connect(_on_enemy_reached)
	enemy.died.connect(_on_enemy_died)
	_board_view.add_child(enemy)
	enemy.set_max_hp(enemy.max_hp * (enemy_max_hp / 40.0))
	enemy.setup(points, enemy.speed_cells)
	enemy.speed *= _rng.randf_range(0.85, 1.15)
	enemy.waypoint = waypoint
	_enemies.append(enemy)
	_spawned_total += 1
	_toast("出怪：" + enemy.display_name)
	_update_stats()


## 按 L 时随机出的敌人：小船最常见，炸弹船最少。
func _random_enemy_type() -> int:
	var roll := _rng.randf()
	if roll < 0.50:
		return 0
	if roll < 0.70:
		return 1
	if roll < 0.85:
		return 2
	return 3


## 随机挑一个中途要绕过去的空格子；没有合适的就返回 -1。
func _pick_waypoint(spawn: Vector2i) -> Vector2i:
	for attempt in 14:
		var cell := Vector2i(_rng.randi_range(0, board.columns - 1), _rng.randi_range(0, board.rows - 1))
		if not board.is_inside(cell) or board.is_blocked(cell):
			continue
		if cell == board.base_cell or board.spawn_cells.has(cell):
			continue
		var from_spawn := board.hex_distance(spawn, cell)
		if from_spawn < 2 or from_spawn > 7:
			continue
		if board.hex_distance(cell, board.base_cell) < 3:
			continue
		return cell
	return Vector2i(-1, -1)


## 拼出「起点 →（可选的中途格）→ 基地」的格子序列。
func _route_through(from: Vector2i, waypoint: Vector2i) -> Array[Vector2i]:
	var direct := board.find_path(from, board.base_cell)
	if waypoint == Vector2i(-1, -1):
		return direct
	var head := board.find_path(from, waypoint)
	var tail := board.find_path(waypoint, board.base_cell)
	if head.is_empty() or tail.is_empty():
		return direct
	var merged: Array[Vector2i] = head.duplicate()
	merged.append_array(tail.slice(1))
	return merged


func _on_enemy_reached(enemy) -> void:
	if _is_over:
		return
	_enemies.erase(enemy)
	_reached += 1
	_base_hp = maxi(0, _base_hp - 1)
	enemy.queue_free()
	_update_stats()
	if _base_hp <= 0:
		_game_over()


## 敌人被打死：从场上名单里移除并计入击杀。
func _on_enemy_died(enemy) -> void:
	_enemies.erase(enemy)
	if enemy.counts_as_kill:
		_kills += 1
	_update_stats()


func _repath_enemies() -> void:
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		var cell := board.world_to_cell(enemy.position)
		if not board.is_inside(cell):
			continue
		var waypoint: Vector2i = enemy.waypoint
		if waypoint != Vector2i(-1, -1):
			var still_ahead: bool = board.hex_distance(cell, board.base_cell) > board.hex_distance(waypoint, board.base_cell)
			if not still_ahead or board.is_blocked(waypoint):
				waypoint = Vector2i(-1, -1)
				enemy.waypoint = waypoint
		var cells := _route_through(cell, waypoint)
		if cells.size() > 1:
			enemy.follow_cells(cells, board)


func _refresh_paths() -> void:
	_spawn_paths.clear()
	for spawn in board.spawn_cells:
		var cells := board.find_path(spawn, board.base_cell)
		if cells.is_empty():
			continue
		var points := PackedVector2Array()
		for cell in cells:
			points.append(board.cell_center(cell))
		_spawn_paths.append(points)
	_board_view.preview_paths = _spawn_paths
	_board_view.queue_redraw()


# ---------------------------------------------------------------- 界面

func _mouse_cell() -> Vector2i:
	var local: Vector2 = _board_view.to_local(get_global_mouse_position())
	var cell: Vector2i = board.world_to_cell(local)
	if not board.is_inside(cell) or board.is_removed(cell):
		return Vector2i(-1, -1)
	return cell


func _update_hover() -> void:
	var cell := _mouse_cell()
	if cell == _board_view.hover_cell:
		return
	_board_view.hover_cell = cell
	_board_view.hover_valid = _can_place(cell)
	_board_view.queue_redraw()


func _update_stats() -> void:
	_refresh_panel()


func _update_resources() -> void:
	_refresh_panel()


## 把当前数值刷到 J 面板上（面板关着时什么都不用做）。
func _refresh_panel() -> void:
	if _stats_panel == null or not _stats_panel.visible:
		return
	_stats_panel.update_values({
		"command": "%d / %d" % [floori(_command), int(command_max)],
		"supplies": "%d / %d" % [floori(_supplies), int(supplies_max)],
		"base_hp": "%d / %d" % [_base_hp, base_max_hp],
		"enemies": str(_enemies.size()),
		"units": str(_unit_nodes.size()),
		"kills": str(_kills),
		"arrived": str(_reached),
	})
	_stats_panel.set_message(_last_message)


## 基地血量耗尽：暂停游戏，弹出失败页面。
func _game_over() -> void:
	if _is_over:
		return
	_is_over = true
	if _placing:
		_cancel_place_mode()
	if _selected_unit_cell != Vector2i(-1, -1):
		_select_tower(Vector2i(-1, -1))
	_board_view.drag_target_cell = Vector2i(-1, -1)
	_board_view.queue_redraw()
	if _dragging:
		var held_tower = _drag_tower
		var from_cell := _drag_from_cell
		_end_drag_visuals()
		if held_tower != null and is_instance_valid(held_tower):
			held_tower.set_held(false)
			held_tower.position = board.cell_center(from_cell)
	get_tree().paused = true
	var page = GAME_OVER_SCENE.instantiate()
	add_child(page)
	page.set_arrived(_reached)
	page.retry_requested.connect(_on_retry_requested)
	page.menu_requested.connect(_on_menu_requested)


func _on_retry_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


## 现在没有常驻 UI，提示信息存起来，按 J 打开面板时显示在「提示」一栏。
func _toast(message: String) -> void:
	_last_message = message


## 打开视觉小说：顶部蓝色「剧情 (V)」按钮和 V 键都走这里。
## VN 是全局单例（见 scripts/vn_manager.gd），所以任何场景、任何时刻都能这样调。
func _open_vn() -> void:
	VN.open_file(VN_STORY_PATH)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
