extends SceneTree

## 把视觉小说的页面分别截图，方便检查颜色和排版。
## 用法：
##   Godot.exe --path . --windowed --resolution 1920x1080 \
##     --script res://tools/vn_preview.gd -- --outdir=res://docs/images

const STORY_PATH := "res://vn/first_level.json"

var _outdir := "res://docs/images"
var _vn


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outdir="):
			_outdir = arg.trim_prefix("--outdir=")

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	await process_frame

	var packed: PackedScene = load("res://scenes/game.tscn")
	if packed == null:
		printerr("无法加载游戏场景")
		quit(1)
		return
	root.add_child(packed.instantiate())
	for i in 20:
		await process_frame

	_vn = root.get_node_or_null("VN")
	if _vn == null:
		printerr("找不到 VN 单例，检查 project.godot 的 [autoload]")
		quit(1)
		return

	# 截图时关掉打字机、把自动翻页的停留时间拉长，方便稳定地停在某一页
	_vn.open_file(STORY_PATH, {"pause": false, "typewriter_speed": 0, "page_hold": 30.0})
	await _settle(0.45)
	await _shot("vn_page1_ready")

	_vn.advance()
	await _settle(0.25)
	await _shot("vn_page1")

	_vn.advance()
	await _settle(0.5)
	_vn.advance()
	await _settle(0.25)
	await _shot("vn_page2")

	_vn.advance()
	await _settle(0.5)
	_vn.advance()
	await _settle(0.25)
	await _shot("vn_page3")

	_vn.close()
	await _settle(0.45)
	await _shot("vn_closed_hud")
	quit()


func _settle(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_outdir))
	var path := _outdir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	if err == OK:
		print("已保存 ", path)
	else:
		printerr("保存失败 ", path, " err=", err)
