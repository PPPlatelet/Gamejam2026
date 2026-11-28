extends Node

## 全局视觉小说控制器（自动加载单例，名字叫 VN）。
##
## 因为做成了 Autoload，所以任何场景、任何脚本、任何时刻都能调用，例如：
##   VN.open_file("res://vn/first_level.json")
##   VN.open_file("res://vn/first_level.json", {"pause": true, "typewriter_speed": 30})
##
## 默认行为：
##   * 打开时暂停游戏（敌人 / 计时全部停住），关闭后恢复原来的暂停状态；
##   * 小说层永远盖在所有 HUD 和场景之上（CanvasLayer 100）；
##   * 每页先显示颜色和蓝色按钮，玩家点按钮后文字逐字出现，
##     文字显示完自动翻到下一页，最后一页结束自动关闭；
##   * 支持 VnStory 对象、字典、JSON 文件三种内容来源。

signal opened(story_title: String)
signal closed
signal page_changed(page_index: int, page_count: int)
signal finished

const LAYER_SCENE := preload("res://scenes/vn/vn_layer.tscn")
const DEFAULT_STORY_PATH := "res://vn/first_level.json"
const VnStoryClass := preload("res://scripts/vn_story.gd")

const DEMO := "res://vn/demo.json"
const TITLE_SCENE := "res://scenes/main_menu.tscn"
var storage := preload("res://scripts/vn_storage.gd").new()
var menu := preload("res://scripts/vn_menu.gd").new()
var _from_title := false
var _return_title := false
var is_open := false

var _layer
var _paused_before := false
var _closing := false


func _ready() -> void:
	storage.load_settings()
	menu.controller = self
	add_child(menu)


func show_title() -> void:
	menu.begin("title", "视觉小说")
	menu.action("新游戏", new_game)
	menu.action("读档", show_load_menu.bind(show_title))
	menu.action("继续游戏", _continue_from_menu, can_continue())
	menu.action("流程图", show_flowchart.bind(show_title))
	menu.action("系统设置", show_settings.bind(show_title))
	menu.action("结束游戏", end_game)


func new_game(path: String = DEMO) -> bool:
	if not open_file(path, {"auto_advance": false}):
		return false
	_from_title = true
	menu.close()
	save_game("resume")
	return true


func can_continue() -> bool:
	return _story_for_slot(storage.read_slot("resume")) != null


func continue_game() -> bool:
	return load_game("resume")


func _continue_from_menu() -> void:
	if not continue_game():
		menu.status.text = "继续进度不可用"


func save_game(slot := "1") -> bool:
	if _layer == null or (not is_open and not _closing):
		return false
	var state: Dictionary = _layer.snapshot()
	return storage.write_slot(slot, state)


func quick_save() -> bool:
	return save_game("quick")


func quick_load() -> bool:
	return load_game("quick")


func _story_for_slot(state: Dictionary) -> VnStory:
	var path = state.get("story", "")
	if not path is String or not path.begins_with("res://") or not FileAccess.file_exists(path):
		return null
	var story := VnStoryClass.from_json_file(path)
	return story if story != null and story.accepts_save(state) else null


func load_game(slot := "1") -> bool:
	var state: Dictionary = storage.read_slot(slot)
	var story := _story_for_slot(state)
	if story == null:
		return false
	var from_title := _from_title or not is_open
	if not open_story(story, {"auto_advance": false}):
		return false
	_from_title = from_title
	menu.close()
	_layer.restore(state)
	save_game("resume")
	return true


func show_load_menu(parent_menu := Callable()) -> void:
	menu.slots(false, parent_menu)


func show_settings(parent_menu := Callable()) -> void:
	menu.settings(false, parent_menu)


func set_preference(key: String, value: float) -> bool:
	if not storage.configure(key, value):
		return false
	if is_open:
		_layer.apply_preference(key, storage.preferences[key])
	return storage.save_settings()


func show_flowchart(parent_menu := Callable()) -> void:
	var story: VnStory
	var current := ""
	var visited: Array = []
	if is_open:
		story = _layer._story
		current = story.pages[_layer.current_page()].id
		visited = _layer.visited_ids()
	else:
		var state: Dictionary = storage.read_slot("resume")
		story = _story_for_slot(state)
		if story == null:
			story = VnStoryClass.from_json_file(DEMO)
		else:
			current = state.page
			for step in state.get("route", []):
				visited.append(step.id)
	if story != null:
		menu.flow(story, current, visited, parent_menu)


func return_to_title() -> void:
	if is_open:
		_return_title = true
		_layer.request_close()
	else:
		show_title()


func end_game() -> void:
	get_tree().quit()


## 直接用一行代码播放默认剧本。
## source 可以是：
##   null            → 用 DEFAULT_STORY_PATH
##   String          → JSON 文件路径，如 "res://vn/chapter_2.json"
##   Dictionary      → 剧本字典，格式同 JSON
##   VnStory         → 已经解析好的剧本对象
func open(source = null, options: Dictionary = {}) -> bool:
	if source == null:
		return open_file(DEFAULT_STORY_PATH, options)
	if source is String:
		return open_file(source, options)
	if source is Dictionary:
		var story := VnStoryClass.from_dict(source)
		if story == null:
			return false
		return open_story(story, options)
	if typeof(source) == TYPE_OBJECT and source.get_script() == VnStoryClass:
		return open_story(source, options)
	push_error("视觉小说：open() 只接受 null / 文件路径 / 字典 / VnStory")
	return false


## 从 JSON 文件播放。
## options:
##   pause             bool   打开时是否暂停游戏，默认 true
##   typewriter_speed  float  每秒出现多少字，默认 30；0 = 瞬间显示
##   auto_advance      bool   文字读完后是否自动翻页，默认 true
##   page_hold         float  自动翻页前停留多少秒，默认 1.6
func open_file(path: String = DEFAULT_STORY_PATH, options: Dictionary = {}) -> bool:
	var story := VnStoryClass.from_json_file(path)
	if story == null:
		return false
	return open_story(story, options)


## 播放一个已经解析好的 VnStory。
func open_story(story, options: Dictionary = {}) -> bool:
	if story == null or story.pages.is_empty():
		push_error("视觉小说：剧本为空，无法播放")
		return false

	_ensure_layer()
	var already_open := is_open
	if not already_open:
		if _closing:
			# 上一段正在淡出时又被打开：撤销那次关闭和暂停，按这次的要求重新来
			get_tree().paused = _paused_before
		else:
			_paused_before = get_tree().paused
		_closing = false
	is_open = true

	_return_title = false
	var playback := {"typewriter_speed": storage.preferences.speed, "page_hold": storage.preferences.delay}
	playback.merge(options, true)
	_layer.show_story(story, playback)

	get_tree().paused = _paused_before or bool(options.get("pause", true))

	if not already_open:
		opened.emit(story.title)
	return true


## 玩家中途关闭 / 剧本播放完时调用；会淡出并恢复游戏。
func close() -> void:
	if not is_open or _layer == null:
		return
	is_open = false
	_closing = true
	_layer.request_close()


## 相当于玩家点了蓝色按钮；给「自动播放」之类的功能用。
func advance() -> void:
	if _layer != null and is_open:
		_layer.advance()


## 当前在第几页（从 0 开始）；没在播放时返回 -1。
func current_page() -> int:
	if _layer == null or not is_open:
		return -1
	return _layer.current_page()


# ---------------------------------------------------------------- 内部

func _ensure_layer() -> void:
	if _layer != null:
		return
	_layer = LAYER_SCENE.instantiate()
	_layer.controller = self
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.finished.connect(_on_layer_finished)
	_layer.closed.connect(_on_layer_closed)
	_layer.page_changed.connect(func(page_index: int, page_count: int) -> void:
		page_changed.emit(page_index, page_count))
	get_tree().root.add_child(_layer)


func _on_layer_finished() -> void:
	finished.emit()


func _on_layer_closed() -> void:
	is_open = false
	_closing = false
	get_tree().paused = _paused_before
	var title := _return_title or _from_title
	var relocate := _return_title
	_return_title = false
	_from_title = false
	closed.emit()
	if title:
		var scene := get_tree().current_scene
		if relocate and scene != null and scene.scene_file_path != TITLE_SCENE:
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE_SCENE)
		show_title()
