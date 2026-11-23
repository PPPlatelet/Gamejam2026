extends SceneTree

var failed := false
var vn
var layer
var directory: String

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		print("[OK] ", label)
	else:
		failed = true
		printerr("[FAIL] ", label)

func press(text: String) -> bool:
	for button in vn.menu.body.find_children("*", "Button", true, false):
		if button.text.begins_with(text) and not button.disabled:
			button.pressed.emit()
			return true
	check(false, "找不到可用按钮 " + text)
	return false

func _run() -> void:
	vn = root.get_node("VN")
	var args := OS.get_cmdline_user_args()
	directory = OS.get_temp_dir().path_join("vn-system-check-%s" % OS.get_process_id()) if args.size() < 2 else args[1]
	DirAccess.make_dir_recursive_absolute(directory)
	vn.storage.directory = directory
	if args.has("--restore-check"):
		vn.storage.load_settings()
		check(vn.continue_game() and vn.current_page() == 2, "新进程从继续点回到 B")
		check(vn.quick_load() and vn.current_page() == 0, "新进程保留独立快速槽")
		check(vn.storage.preferences.volume == 0.4, "新进程读取系统设置")
		quit(1 if failed else 0)
		return
	var scene: PackedScene = load("res://scenes/main_menu.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	main.get_node("%DemoButton").pressed.emit()
	check(vn.menu.kind == "title" and vn.menu.body.get_child_count() == 6, "标题提供六个入口")
	check(not vn.can_continue(), "空槽禁用继续")
	press("流程图")
	var graph: GraphEdit = vn.menu.body.get_child(0)
	check(graph.get_connection_list().size() == 4, "标题流程图展示分支和汇合")
	vn.menu.go_back()
	press("系统设置")
	var sliders: Array = vn.menu.body.find_children("*", "HSlider", true, false)
	check(sliders.size() == 3, "设置提供语速、停留时间和音量")
	sliders[2].value = 0
	check(AudioServer.is_bus_mute(0), "主音量静音生效")
	sliders[2].value = 40
	check(not AudioServer.is_bus_mute(0) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.4), "主音量恢复至 40%")
	vn.menu.go_back()
	press("新游戏")
	layer = vn._layer
	check(vn.is_open and paused and layer._backdrop.texture != null and layer._portrait.texture != null, "新游戏进入带立绘的场景")
	layer.navigate("next_scene")
	check(vn.current_page() == 0 and layer._choices.get_child_count() == 2, "场景跳转在未选分支停下")
	layer._toggle_auto()
	await create_timer(1.8).timeout
	check(vn.current_page() == 0, "自动模式等待玩家选择")
	check(vn.quick_save(), "快速保存选项页")
	layer._choices.get_child(1).pressed.emit()
	await create_timer(0.8).timeout
	check(vn.current_page() == 2 and layer._phase == layer.Phase.HOLD, "路线 B 自动出字")
	layer._show_history()
	await create_timer(1.8).timeout
	check(vn.current_page() == 2 and "› 路线 B" in layer._archive.get_node("Body/Log").text, "历史记录与暂停推进")
	layer._hide_history()
	layer._tools.get_node("Save").pressed.emit()
	press("存档 2")
	check(vn.storage.read_slot("2").page == "b", "手动存档和快速槽独立")
	layer.navigate("next_scene")
	check(vn.current_page() == 3, "跳到下一个场景")
	layer.navigate("prev_scene")
	check(vn.current_page() == 2, "上一个场景沿 B 路线返回")
	layer.navigate("line")
	check(vn.current_page() == 0 and layer._history.size() == 1, "上一句撤销旧选择")
	layer._choices.get_child(0).pressed.emit()
	await create_timer(0.4).timeout
	layer.navigate("next_choice")
	check(vn.current_page() == 3, "无后续选项时停到末句")
	layer.navigate("prev_choice")
	check(vn.current_page() == 0 and layer._choices.get_child_count() == 2, "返回上一个选项可以重选")
	layer._choices.get_child(1).pressed.emit()
	await create_timer(0.4).timeout
	layer.navigate("forward")
	await create_timer(0.5).timeout
	check(vn.current_page() == 3 and layer._travel == 0, "连续快进停在结尾")
	layer.navigate("rewind")
	await create_timer(0.7).timeout
	check(vn.current_page() == 0 and layer._travel == 0, "连续快退停在起点")
	layer._hide_hud()
	check(layer._backdrop.visible and not layer._tools.visible, "隐藏 HUD 保留场景画面")
	var input := InputEventKey.new()
	input.keycode = KEY_H
	input.pressed = true
	root.push_input(input, true)
	check(not layer._hud_hidden and layer._tools.visible, "按键恢复 HUD")
	check(vn.load_game("2") and vn.current_page() == 2 and layer._history.size() == 3, "恢复正文、分支和历史")
	var before: Dictionary = layer.snapshot()
	vn.storage.write_json(vn.storage.slot_path("3"), {"broken": true})
	check(not vn.load_game("3") and layer.snapshot() == before, "坏档不更改正在阅读的内容")
	var legacy := before.duplicate(true)
	legacy.version = 1
	legacy.erase("route")
	vn.storage.write_slot("1", legacy)
	check(vn.load_game("1") and layer._history.size() == 3, "兼容第一版单槽存档")
	check(vn.quick_load() and vn.current_page() == 0, "快速读取独立槽")
	vn.return_to_title()
	await create_timer(0.35).timeout
	check(not vn.is_open and not paused and vn.menu.kind == "title", "局内安全返回标题")
	press("读档")
	press("存档 2")
	check(vn.current_page() == 2, "标题页可以直接读档")
	vn.return_to_title()
	await create_timer(0.35).timeout
	press("继续游戏")
	check(vn.current_page() == 2, "继续上次离开的页面")
	# 验证战斗内入口能彻底切回标题，并且文件存档可从标题继续读取。
	vn.close()
	await create_timer(0.35).timeout
	vn.menu.close()
	change_scene_to_file("res://scenes/game.tscn")
	await scene_changed
	vn.open_file("res://vn/first_level.json")
	vn.return_to_title()
	await create_timer(0.5).timeout
	check(current_scene.scene_file_path == vn.TITLE_SCENE and vn.menu.kind == "title" and not paused, "战斗内返回标题完成场景切换")
	vn.menu.close()
	var fixture := {"pages": [{"id":"p1", "scene":"s1", "text":"1"},
		{"id":"p2", "scene":"s1", "text":"2"}, {"id":"p3", "scene":"s2", "text":"3"},
		{"id":"p4", "scene":"s2", "text":"4", "choices":[{"text":"A", "next":"p1"}]}]}
	vn.open(fixture, {"auto_advance":false})
	layer.navigate("next_scene")
	check(vn.current_page() == 2, "场景跳转越过同场对白")
	layer.navigate("next_choice")
	check(vn.current_page() == 3 and layer._choices.get_child_count() == 1, "前进精确停在下一选项")
	layer.navigate("prev_scene")
	check(vn.current_page() == 0, "跨场景回到前一场的开头")
	check(vn.load_game("2") and vn.save_game("resume"), "保存跨进程检查点")
	print("VN_FRAMEWORK_FAILED" if failed else "VN_FRAMEWORK_OK")
	quit(1 if failed else 0)
