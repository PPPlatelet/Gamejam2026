class_name HexBoardView
extends Node2D

## 把 HexBoard 画出来：基地 / 出生点底色 + 鼠标悬停高亮 + 敌人路线。
## 背景图由 game.tscn 里的 Backdrop 层铺满，这里不再逐格贴地块；
## 格子只保留判定（悬停、放船、寻路），平时不画网格。
## 拖塔时（show_grid = true）会铺一层淡白并显示网格，
## drag_cell 标记塔下方经过的格子，drag_target_cell 标记松手后的目标格。

const HexBoardClass := preload("res://scripts/hex_board.gd")

const LINE_COLOR := Color(0.78, 0.81, 0.85)
const LINE_WIDTH := 0.035
const BASE_FILL := Color(0.30, 0.58, 0.95, 0.25)
const SPAWN_FILL := Color(1.00, 0.45, 0.30, 0.18)
const HOVER_OK := Color(0.25, 0.75, 0.40, 0.35)
const HOVER_BAD := Color(0.90, 0.25, 0.25, 0.35)
const SELECT_FILL := Color(1.00, 0.82, 0.25, 0.30)
const SELECT_LINE := Color(1.00, 0.72, 0.10, 0.95)
const PATH_COLOR := Color(0.15, 0.45, 0.95, 0.30)
const PATH_WIDTH := 0.10
const ARROW_COLOR := Color(0.95, 0.45, 0.30, 0.85)
const GRID_VEIL := Color(1.0, 1.0, 1.0, 0.55)
const DRAG_COLOR := Color(0.40, 0.86, 0.93)
const DRAG_BAD := Color(0.92, 0.32, 0.30)

var board: HexBoardClass
var hover_cell := Vector2i(-1, -1)
var hover_valid := false
var selected_cell := Vector2i(-1, -1)
var show_paths := false
var show_numbers := false        # H 键切换：每格显示序号（行 × 列数 + 列 + 1）
var preview_paths: Array = []   # Array[PackedVector2Array]

var show_grid := false           # 拖塔时显示网格
var drag_cell := Vector2i(-1, -1)          # 塔当前压住的格子（第二个图）
var drag_target_cell := Vector2i(-1, -1)   # 松手后的目标格（第三个图）
var drag_target_valid := true


func _draw() -> void:
	if board == null:
		return

	if show_grid:
		for row in board.rows:
			for column in board.columns:
				var grid_cell := Vector2i(column, row)
				if board.is_removed(grid_cell):
					continue
				draw_colored_polygon(board.cell_polygon(grid_cell), GRID_VEIL)

	for row in board.rows:
		for column in board.columns:
			var cell := Vector2i(column, row)
			if board.is_removed(cell):
				continue
			var fill := Color.TRANSPARENT
			if cell == board.base_cell:
				fill = BASE_FILL
			elif board.spawn_cells.has(cell):
				fill = SPAWN_FILL
			if cell == selected_cell:
				fill = SELECT_FILL
			if cell == hover_cell:
				fill = HOVER_OK if hover_valid else HOVER_BAD
			if fill.a > 0.0:
				draw_colored_polygon(board.cell_polygon(cell, 0.985), fill)

	if show_grid:
		for row in board.rows:
			for column in board.columns:
				var line_cell := Vector2i(column, row)
				if board.is_removed(line_cell):
					continue
				var points := board.cell_polygon(line_cell, 0.985)
				var closed := points.duplicate()
				closed.append(points[0])
				draw_polyline(closed, LINE_COLOR, LINE_WIDTH, true)

	if show_paths:
		for path in preview_paths:
			draw_polyline(path, PATH_COLOR, PATH_WIDTH, true)

	if board.is_inside(selected_cell):
		var selected_points := board.cell_polygon(selected_cell, 0.985)
		var selected_closed := selected_points.duplicate()
		selected_closed.append(selected_points[0])
		draw_polyline(selected_closed, SELECT_LINE, LINE_WIDTH * 2.4, true)

	_draw_drag_marks()

	for cell in board.spawn_cells:
		_draw_spawn_arrow(cell)

	if show_numbers:
		_draw_numbers()


## 拖塔时的两个格子标记：经过的格子是细蓝框，目标格带六个小刻度。
func _draw_drag_marks() -> void:
	if board.is_inside(drag_cell) and not board.is_removed(drag_cell) and drag_cell != drag_target_cell:
		var under_points := board.cell_polygon(drag_cell, 0.96)
		var under_closed := under_points.duplicate()
		under_closed.append(under_points[0])
		draw_colored_polygon(under_points, Color(DRAG_COLOR.r, DRAG_COLOR.g, DRAG_COLOR.b, 0.10))
		draw_polyline(under_closed, DRAG_COLOR, 0.055, true)

	if board.is_inside(drag_target_cell) and not board.is_removed(drag_target_cell):
		var color := DRAG_COLOR if drag_target_valid else DRAG_BAD
		var target_points := board.cell_polygon(drag_target_cell, 0.96)
		var target_closed := target_points.duplicate()
		target_closed.append(target_points[0])
		draw_colored_polygon(target_points, Color(color.r, color.g, color.b, 0.12))
		draw_polyline(target_closed, color, 0.06, true)

		var center := board.cell_center(drag_target_cell)
		for i in 6:
			var vertex: Vector2 = target_points[i]
			var outward := (vertex - center).normalized()
			draw_line(vertex - outward * 0.05, vertex + outward * 0.10, color, 0.05, true)


## 每格画一个编号：列字母 + 行号（A1、B3……），行从上往下 1 开始。
## 文字用 1/scale 的原尺寸绘制，所以不管棋盘缩放多少，屏幕上都是固定字号。
func _draw_numbers() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	const FONT_SIZE := 16
	var inverse_scale := 1.0 / maxf(scale.x, 0.0001)
	var baseline := (font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
	var fill_color := Color(0.08, 0.10, 0.14, 1.0)
	var outline_color := Color(1.0, 1.0, 1.0, 0.92)

	for row in board.rows:
		for column in board.columns:
			var cell := Vector2i(column, row)
			if board.is_removed(cell):
				continue
			var text := "%s%d" % [_column_label(column), row + 1]
			var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			draw_set_transform(board.cell_center(cell), 0.0, Vector2(inverse_scale, inverse_scale))
			var origin := Vector2(-text_width * 0.5, baseline)
			draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, outline_color)
			draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, fill_color)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 列号转字母：0 → A、1 → B……25 → Z、26 → AA。
func _column_label(column: int) -> String:
	var label := ""
	var value := column
	while true:
		label = String.chr(65 + value % 26) + label
		value = value / 26 - 1
		if value < 0:
			break
	return label


func _draw_spawn_arrow(cell: Vector2i) -> void:
	var center := board.cell_center(cell)
	var direction := Vector2.DOWN if cell.y == 0 else Vector2.LEFT
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		center + direction * 0.42,
		center - direction * 0.12 + side * 0.26,
		center - direction * 0.12 - side * 0.26,
	]), ARROW_COLOR)
