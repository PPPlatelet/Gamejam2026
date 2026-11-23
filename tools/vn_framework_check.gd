extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		print("[OK] ", label)
	else:
		failed = true
		printerr("[FAIL] ", label)

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main_menu.tscn")
	var menu := scene.instantiate()
	root.add_child(menu)
	menu.get_node("%DemoButton").pressed.emit()
	var vn = root.get_node("VN")
	var layer = vn._layer
	var test_path := "user://vn-check-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	layer._save_path = test_path
	check(vn.is_open and paused, "主菜单打开试玩并暂停")
	check(layer._backdrop.texture != null and layer._portrait.texture != null, "背景和立绘加载")
	vn.advance()
	vn.advance()
	check(layer._choices.get_child_count() == 2, "快显后出现两个选项")
	layer._tools.get_node("Auto").pressed.emit()
	await create_timer(1.9).timeout
	check(vn.current_page() == 0, "自动模式等待选择")
	layer._choices.get_child(1).pressed.emit()
	await create_timer(0.65).timeout
	check(vn.current_page() == 2 and layer._phase == layer.Phase.HOLD, "路线 B 自动出字")
	layer._tools.get_node("History").pressed.emit()
	await create_timer(1.9).timeout
	check(vn.current_page() == 2 and layer._archive.visible, "回看时冻结自动播放")
	check("› 路线 B" in layer._archive.get_node("Body/Log").text, "回看包含实际选择")
	layer._archive.get_node("Body/Back").pressed.emit()
	layer._tools.get_node("Save").pressed.emit()
	layer._tools.get_node("Save").pressed.emit()
	check(FileAccess.file_exists(test_path) and layer._hint.text == "进度已保存", "可以覆盖同一槽")
	vn.close()
	await create_timer(0.35).timeout
	check(not paused and menu.is_inside_tree(), "关闭回到菜单")
	menu.get_node("%DemoButton").pressed.emit()
	layer._tools.get_node("Load").pressed.emit()
	check(vn.current_page() == 2 and layer._history.size() == 3 and layer._phase == layer.Phase.HOLD, "重新打开后还原分支和已读记录")
	vn.advance()
	await create_timer(0.4).timeout
	check(vn.current_page() == 3, "路线 B 汇入结束页")
	vn.advance()
	vn.advance()
	vn.advance()
	await create_timer(0.35).timeout
	check(not vn.is_open and not paused, "读到结尾返回菜单")
	menu.get_node("%DemoButton").pressed.emit()
	vn.advance()
	vn.advance()
	layer._choices.get_child(0).pressed.emit()
	await create_timer(0.4).timeout
	check(vn.current_page() == 1, "路线 A 独立可达")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	layer._tools.get_node("Load").pressed.emit()
	check(vn.current_page() == 1 and "存档" in layer._hint.text, "坏档保留当前页")
	DirAccess.remove_absolute(test_path)
	vn.close()
	await create_timer(0.35).timeout
	print("VN_FRAMEWORK_FAILED" if failed else "VN_FRAMEWORK_OK")
	quit(1 if failed else 0)
