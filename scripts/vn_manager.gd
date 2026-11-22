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

var is_open := false

var _layer
var _paused_before := false
var _closing := false


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

	_layer.show_story(story, options)

	if bool(options.get("pause", true)):
		get_tree().paused = true

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
	closed.emit()
