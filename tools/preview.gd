extends SceneTree

## 渲染指定场景并保存截图，用来检查画面。
## 用法：Godot.exe --path . --windowed --resolution 1920x1080 --script res://tools/preview.gd -- --out=res://shot.png --frames=180

const DEFAULT_SCENE := "res://scenes/game.tscn"
const DEFAULT_OUT := "res://preview.png"


func _initialize() -> void:
	var scene_path := DEFAULT_SCENE
	var out_path := DEFAULT_OUT
	var wait_frames := 3
	var window_size := Vector2i(1920, 1080)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames="):
			wait_frames = maxi(1, arg.trim_prefix("--frames=").to_int())
		elif arg.begins_with("--window="):
			var parts := arg.trim_prefix("--window=").split("x")
			if parts.size() == 2:
				window_size = Vector2i(parts[0].to_int(), parts[1].to_int())

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("无法加载场景：", scene_path)
		quit(1)
		return

	# 测试时强制窗口化，避免占满整个屏幕
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	await process_frame
	await process_frame

	var node := packed.instantiate()
	root.add_child(node)

	print("窗口尺寸：", DisplayServer.window_get_size(), " 视口：", root.get_visible_rect().size)

	for i in wait_frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("已保存截图：", out_path, " 尺寸：", img.get_size())
	quit()
