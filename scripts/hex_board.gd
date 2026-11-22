class_name HexBoard
extends RefCounted

## 尖顶朝上的六边形棋盘，使用 odd-r 偏移坐标（列, 行）。
##
## 逻辑坐标以「六边形外接圆半径 = 1」为单位，具体显示多大由 HexBoardView 统一缩放，
## 所以寻路、格子大小和屏幕分辨率互不影响。

const HEX_WIDTH := 1.7320508075688772   # 六边形宽 = sqrt(3) × 半径，也是相邻两列的中心距
const ROW_STEP := 1.5                    # 相邻两行的中心距 = 1.5 × 半径

# 偶数行 / 奇数行的六个邻居偏移（odd-r）
const NEIGHBORS_EVEN := [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const NEIGHBORS_ODD := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]

var columns: int
var rows: int
var base_cell := Vector2i.ZERO
var spawn_cells: Array[Vector2i] = []
var blocked: Dictionary = {}   # Vector2i -> "obstacle" / "tower" / "check"
var removed: Dictionary = {}   # Vector2i -> true，直接删掉的格子（不参与寻路/放置/悬停）


func _init(p_columns: int, p_rows: int) -> void:
	columns = maxi(1, p_columns)
	rows = maxi(1, p_rows)


## 整张棋盘的尺寸（半径 = 1 的单位）
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(HEX_WIDTH * (columns + 0.5), 2.0 + ROW_STEP * (rows - 1)))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func is_blocked(cell: Vector2i) -> bool:
	return blocked.has(cell) or removed.has(cell)


func is_removed(cell: Vector2i) -> bool:
	return removed.has(cell)


func remove_cell(cell: Vector2i) -> void:
	removed[cell] = true


func block(cell: Vector2i, kind: String) -> void:
	blocked[cell] = kind


func unblock(cell: Vector2i) -> void:
	blocked.erase(cell)


func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in rows:
		for column in columns:
			cells.append(Vector2i(column, row))
	return cells


## 格子中心（以整张棋盘中心为原点）
func cell_center(cell: Vector2i) -> Vector2:
	var center := Vector2(
		HEX_WIDTH * (cell.x + 0.5 * (cell.y & 1)) + HEX_WIDTH * 0.5,
		1.0 + ROW_STEP * cell.y
	)
	return center - bounds().size * 0.5


func cell_polygon(cell: Vector2i, radius := 1.0) -> PackedVector2Array:
	var center := cell_center(cell)
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i + 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets: Array = NEIGHBORS_ODD if (cell.y & 1) == 1 else NEIGHBORS_EVEN
	for offset in offsets:
		var neighbor: Vector2i = cell + offset
		if is_inside(neighbor):
			result.append(neighbor)
	return result


func to_cube(cell: Vector2i) -> Vector3i:
	var q := cell.x - (cell.y - (cell.y & 1)) / 2
	return Vector3i(q, cell.y, -q - cell.y)


## 两格之间的六边形距离（不考虑障碍）
func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var cube_a := to_cube(a)
	var cube_b := to_cube(b)
	return maxi(absi(cube_a.x - cube_b.x), maxi(absi(cube_a.y - cube_b.y), absi(cube_a.z - cube_b.z)))


## 把棋盘本地坐标换算成格子（返回的格子可能越界，用 is_inside 判断）
func world_to_cell(local_position: Vector2) -> Vector2i:
	# 先换回「左上角为原点」的坐标：cell_center 里加了半格宽 + 半径的偏移，
	# 再整体居中了，这里把这两个常量减回去，否则识别会整体偏一格。
	var p := local_position + bounds().size * 0.5
	p.x -= HEX_WIDTH * 0.5
	p.y -= 1.0
	var q := (sqrt(3.0) / 3.0) * p.x - p.y / 3.0
	var r := (2.0 / 3.0) * p.y
	var axial := _cube_round(q, r)
	var column := axial.x + (axial.y - (axial.y & 1)) / 2
	return Vector2i(column, axial.y)


func _cube_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rounded_q := roundi(q)
	var rounded_r := roundi(r)
	var rounded_s := roundi(s)
	var dq := absf(rounded_q - q)
	var dr := absf(rounded_r - r)
	var ds := absf(rounded_s - s)
	if dq > dr and dq > ds:
		rounded_q = -rounded_r - rounded_s
	elif dr > ds:
		rounded_r = -rounded_q - rounded_s
	return Vector2i(rounded_q, rounded_r)


## A* 寻路，返回从 start 到 goal 的格子序列（含首尾）；走不通返回空数组。
## 每次移动一格，所以这就是「最短路径」。
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not is_inside(start) or not is_inside(goal):
		return path
	if is_blocked(start) or is_blocked(goal):
		return path
	if start == goal:
		path.append(start)
		return path

	var open: Array[Vector2i] = [start]
	var g_score := {start: 0}
	var f_score := {start: hex_distance(start, goal)}
	var came_from := {}

	while not open.is_empty():
		var best_index := 0
		for i in range(1, open.size()):
			var f: int = f_score[open[i]]
			var best_f: int = f_score[open[best_index]]
			# 同样长短的路随机挑一条，避免所有敌人走同一条线。
			if f < best_f or (f == best_f and randf() < 0.5):
				best_index = i
		var current: Vector2i = open[best_index]
		open.remove_at(best_index)

		if current == goal:
			var node := goal
			path.append(node)
			while came_from.has(node):
				node = came_from[node]
				path.append(node)
			path.reverse()
			return path

		var current_g: int = g_score[current]
		for neighbor in neighbors(current):
			if is_blocked(neighbor):
				continue
			var tentative := current_g + 1
			if tentative < int(g_score.get(neighbor, 1000000)):
				came_from[neighbor] = current
				g_score[neighbor] = tentative
				f_score[neighbor] = tentative + hex_distance(neighbor, goal)
				if not open.has(neighbor):
					open.append(neighbor)

	return path
