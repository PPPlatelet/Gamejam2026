extends SceneTree

## 视觉小说的快速自检：验证「点按钮出字 → 自动翻页 → 最后关闭」这条链路。
## 用法：Godot.exe --path . --headless --script res://tools/vn_check.gd

var _failures := 0


func _initialize() -> void:
	var story = VnStory.from_json_file("res://vn/first_level.json")
	_expect(story != null, "剧本能读入")
	if story == null:
		quit(1)
		return
	_expect(story.pages.size() == 3, "剧本有 3 页")
	_expect(story.pages[0].color_key == "red", "第 1 页是红色")
	_expect(story.pages[1].color_key == "yellow", "第 2 页是黄色")
	_expect(story.pages[2].color_key == "white", "第 3 页是白色")

	var packed: PackedScene = load("res://scenes/game.tscn")
	root.add_child(packed.instantiate())
	for i in 5:
		await process_frame

	var vn = root.get_node_or_null("VN")
	_expect(vn != null, "VN 单例存在")
	if vn == null:
		quit(1)
		return

	# 游戏里的 V 键入口
	var key := InputEventKey.new()
	key.keycode = KEY_V
	key.pressed = true
	Input.parse_input_event(key)
	for i in 3:
		await process_frame
	_expect(vn.is_open, "V 键能打开小说")
	vn.close()
	await create_timer(0.4).timeout

	_expect(vn.open_file("res://vn/first_level.json", {
		"pause": false,
		"typewriter_speed": 0,
		"auto_advance": true,
		"page_hold": 0.25,
	}), "能打开剧本")
	_expect(vn.is_open, "打开后 is_open 为 true")
	_expect(vn.current_page() == 0, "停在第 1 页")
	await create_timer(0.3).timeout
	_expect(vn.current_page() == 0, "没点按钮时不会自己出字 / 翻页")

	vn.advance()   # 点第 1 页的蓝色按钮 → 出字 → 自动翻页
	await create_timer(0.9).timeout
	_expect(vn.current_page() == 1, "第 1 页读完后自动到第 2 页")

	vn.advance()
	await create_timer(0.9).timeout
	_expect(vn.current_page() == 2, "第 2 页读完后自动到第 3 页")

	vn.advance()
	await create_timer(1.1).timeout
	_expect(not vn.is_open, "第 3 页读完后自动关闭")
	_expect(vn.current_page() == -1, "关闭后 current_page 为 -1")

	# 暂停 / 恢复
	_expect(vn.open_file("res://vn/first_level.json", {
		"typewriter_speed": 0,
		"auto_advance": false,
	}), "能第二次打开")
	await create_timer(0.2).timeout
	_expect(paused, "打开时游戏被暂停")
	vn.close()
	await create_timer(0.5).timeout
	_expect(not paused, "关闭后游戏恢复运行")

	# 字典剧本 + 自定义颜色 + VN.open() 默认剧本
	_expect(vn.open({
		"title": "内联测试",
		"pages": [{"color": "#2F6BFF", "speaker": "", "text": "内联字典"}]
	}, {"pause": false, "typewriter_speed": 0, "auto_advance": false}), "字典剧本能播放")
	await create_timer(0.2).timeout
	_expect(vn.current_page() == 0, "自定义颜色页停在第 1 页")
	vn.close()
	await create_timer(0.4).timeout

	_expect(vn.open(null, {"pause": false, "typewriter_speed": 0, "auto_advance": false}), "VN.open() 能播默认剧本")
	vn.close()
	await create_timer(0.4).timeout

	if _failures == 0:
		print("VN_CHECK_OK")
		quit(0)
	else:
		printerr("VN_CHECK_FAILED: ", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  [OK] ", label)
	else:
		_failures += 1
		printerr("  [FAIL] ", label)
