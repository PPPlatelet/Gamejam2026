extends SceneTree

## 逻辑自检：寻路是否正确、地图与出生点是否合理、放塔 / 拆塔后是否重新寻路。

const HexBoardClass := preload("res://scripts/hex_board.gd")


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	await process_frame

	var failures := 0

	# --- 1. 纯寻路：没有障碍时路径长度应该等于六边形距离
	var board: HexBoardClass = HexBoardClass.new(6, 5)
	board.base_cell = Vector2i(0, 4)
	var start := Vector2i(5, 0)
	var path := board.find_path(start, board.base_cell)
	print("无障碍：路径 ", path.size(), " 格，理论距离 ", board.hex_distance(start, board.base_cell) + 1)
	if path.size() != board.hex_distance(start, board.base_cell) + 1:
		failures += 1
		print("  FAIL 路径不是最短")

	# --- 2. 挡一格：绕过障碍，且仍然是最短路
	board.block(Vector2i(3, 2), "test")
	var detour := board.find_path(start, board.base_cell)
	print("挡一格：路径 ", detour.size(), " 格，经过障碍=", detour.has(Vector2i(3, 2)))
	if detour.has(Vector2i(3, 2)) or detour.is_empty():
		failures += 1
		print("  FAIL 没有绕开障碍")
	if _bfs_length(board, start, board.base_cell) != detour.size() - 1:
		failures += 1
		print("  FAIL 绕路后不是最短路径")

	# --- 3. 每条路径的每一步都必须相邻
	var adjacent := true
	for i in range(1, detour.size()):
		if not board.neighbors(detour[i - 1]).has(detour[i]):
			adjacent = false
	if not adjacent:
		failures += 1
		print("  FAIL 路径里有不相邻的格子")

	# --- 4. 完全堵死时返回空
	board = HexBoardClass.new(4, 3)
	board.base_cell = Vector2i(0, 2)
	for cell in [Vector2i(0, 1), Vector2i(1, 2)]:
		board.block(cell, "wall")
	print("基地被围死：可走=", not board.find_path(Vector2i(3, 0), board.base_cell).is_empty())
	if not board.find_path(Vector2i(3, 0), board.base_cell).is_empty():
		failures += 1
		print("  FAIL 应该走不通")

	# --- 5. 游戏场景
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame

	var game_board = game.board
	print("棋盘：", game_board.columns, " x ", game_board.rows, "，基地 ", game_board.base_cell, "，出生点 ", game_board.spawn_cells)
	print("障碍物数量：", game_board.blocked.size())
	if game_board.spawn_cells.size() != 6:
		failures += 1
		print("  FAIL 出生点数量不是 6")
	for spawn in game_board.spawn_cells:
		if game_board.find_path(spawn, game_board.base_cell).is_empty():
			failures += 1
			print("  FAIL 出生点 ", spawn, " 走不到基地")

	# 基地的三个邻居全部堵住 → 最后一次放置必须被拒绝
	var base: Vector2i = game_board.base_cell
	var base_neighbors: Array = game_board.neighbors(base)
	print("基地邻居：", base_neighbors)
	var blocked_count := 0
	for neighbor in base_neighbors:
		if game_board.blocked.has(neighbor):
			continue
		if game._can_block(neighbor):
			game._try_build(neighbor)
			blocked_count += 1
		else:
			print("  最后一个邻居 ", neighbor, " 被正确拒绝（会堵死）")

	# 拆掉一座塔后路径应该恢复
	var tower_cells = game._tower_nodes.keys()
	if not tower_cells.is_empty():
		var cell = tower_cells[0]
		game._try_remove(cell)
		print("拆塔后该格是否还挡路：", game_board.is_blocked(cell))
		if game_board.is_blocked(cell):
			failures += 1
			print("  FAIL 拆塔后格子仍然被占用")

	# --- 6. 敌人匀速移动
	var enemy = load("res://scenes/entities/enemy.tscn").instantiate()
	var points := PackedVector2Array([Vector2.ZERO, Vector2(1.732, 0.0)])
	enemy.setup(points, 1.0)
	print("敌人速度：", enemy.speed, "，0.5 秒应移动 ", enemy.speed * 0.5)
	enemy._process(0.5)
	print("  实际 x = ", enemy.position.x)
	if absf(enemy.position.x - enemy.speed * 0.5) > 0.001:
		failures += 1
		print("  FAIL 移动距离不对")
	enemy.free()

	print("结果：", "全部通过" if failures == 0 else "%d 项失败" % failures)
	quit(0 if failures == 0 else 1)


func _bfs_length(board: HexBoardClass, start: Vector2i, goal: Vector2i) -> int:
	var frontier: Array[Vector2i] = [start]
	var distance := {start: 0}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			return distance[current]
		for neighbor in board.neighbors(current):
			if board.is_blocked(neighbor) or distance.has(neighbor):
				continue
			distance[neighbor] = distance[current] + 1
			frontier.append(neighbor)
	return -1
