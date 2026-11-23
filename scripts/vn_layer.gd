extends CanvasLayer

## 视觉小说播放层（画面部分）。
##
## 一页 = 一整屏纯色：底色是剧本里写的红 / 黄 / 白，铺满整个游戏窗口。
## 每一页的流程：
##   1. 先只显示整屏颜色、页码和右下角的蓝色按钮，正文为空；
##   2. 玩家点蓝色按钮（或空格 / 回车）→ 这一页的文字逐字出现；
##   3. 文字显示完 → 停留一小会儿，自动翻到下一页（换颜色）；
##   4. 最后一页读完后自动关闭，回到游戏。
##
## 想改成“读完后等玩家自己点下一页”，把 auto_advance 设成 false。
##
## 平时由全局单例 VN（scripts/vn_manager.gd）创建和调用，
## 不需要手动摆进场景。

signal finished
signal closed
signal page_changed(page_index: int, page_count: int)
signal text_finished(page_index: int)

enum Phase { IDLE, TYPING, HOLD }

const LIGHT_INK := Color(1.0, 0.98, 0.94)
const DARK_INK := Color(0.16, 0.15, 0.13)
const DEFAULT_TYPE_SPEED := 30.0   # 每秒出现多少个字，0 = 瞬间全部出现
const DEFAULT_PAGE_HOLD := 1.6     # 文字显示完后停留多久再自动翻页（秒）
## 正文使用的字体（说话人和正文都统一用它）。
const BODY_FONT_PATH := "res://fonts/ZhiMangXing.ttf"

@onready var _dim: ColorRect = $Dim
@onready var _frame: Control = $PageFrame
@onready var _page: Panel = $PageFrame/Page
@onready var _index_label: Label = $PageFrame/Page/IndexLabel
@onready var _title_label: Label = $PageFrame/Page/TitleLabel
@onready var _rule_top: ColorRect = $PageFrame/Page/RuleTop
@onready var _rule_bottom: ColorRect = $PageFrame/Page/RuleBottom
@onready var _content: Control = $PageFrame/Page/Content
@onready var _idle_hint: Label = $PageFrame/Page/Content/IdleHint
@onready var _speaker_label: Label = $PageFrame/Page/Content/ContentCenter/SpeakerLabel
@onready var _text: RichTextLabel = $PageFrame/Page/Content/ContentCenter/Text
@onready var _dots: HBoxContainer = $PageFrame/Page/Dots
@onready var _hint: Label = $PageFrame/Page/Hint
@onready var _button: Button = $PageFrame/Page/ContinueButton

var _story: VnStory
var _page_index := 0
var _phase := Phase.IDLE
var _type_speed := DEFAULT_TYPE_SPEED
var _type_progress := 0.0
var _total_chars := 1
var _page_hold := DEFAULT_PAGE_HOLD
var _auto_advance := true
var _hold_left := 0.0
var _transitioning := false
var _closing := false
var _page_style: StyleBoxFlat
var _dot_styles: Array[StyleBoxFlat] = []
var _close_tween: Tween
var _open_serial := 0
var _continuous := false
var _history: Array[String] = []
var controller
var _route: Array = []
var _travel := 0
var _travel_wait := 0.0
var _hud_hidden := false
var _checkpoint_pending := false
var _hud_visibility: Dictionary = {}
@onready var _tools: HBoxContainer = $PageFrame/Page/Tools
@onready var _choices: VBoxContainer = $PageFrame/Page/ChoiceScroll/Choices
@onready var _archive: PanelContainer = $PageFrame/Archive
@onready var _backdrop: TextureRect = $PageFrame/Page/Backdrop
@onready var _portrait: TextureRect = $PageFrame/Page/Portrait


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_button.focus_mode = Control.FOCUS_ALL
	_button.pressed.connect(advance)
	_tools.get_node("Auto").pressed.connect(_toggle_auto)
	_tools.get_node("History").pressed.connect(_show_history)
	_tools.get_node("Save").pressed.connect(func(): controller.menu.slots(true, Callable()))
	_tools.get_node("Load").pressed.connect(func(): controller.show_load_menu())
	_tools.get_node("Exit").text = "返回标题"
	_tools.get_node("Exit").pressed.connect(func(): controller.return_to_title())
	var commands := {"快存": _quick.bind(true), "快读": _quick.bind(false), "导航": _navigation_menu,
		"设置": func(): controller.show_settings(), "音量": func(): controller.menu.settings(true, Callable()),
		"流程图": func(): controller.show_flowchart(), "隐藏 HUD": _hide_hud}
	for label in commands:
		var button := Button.new()
		button.text = label
		if label == "导航":
			button.name = "Navigation"
		elif label == "隐藏 HUD":
			button.name = "HideHud"
			button.tooltip_text = "隐藏界面，点击画面或按键恢复"
		button.pressed.connect(commands[label])
		_tools.add_child(button)
	_tools.move_child(_tools.get_node("Exit"), -1)
	_archive.get_node("Body/Back").pressed.connect(_hide_history)
	_apply_body_font()


## 通过资源加载器读取字体，兼容编辑器和导出 PCK 的资源重映射。
func _apply_body_font() -> void:
	var font := load(BODY_FONT_PATH) as FontFile
	if font == null:
		push_warning("视觉小说：正文字体不可用")
		return
	# 这个手写体的空格很窄，占位数字 / 英文之间会粘在一起；用 FontVariation 加宽空格
	var body_font := FontVariation.new()
	body_font.base_font = font
	body_font.spacing_space = 16
	_speaker_label.add_theme_font_override("font", body_font)
	_text.add_theme_font_override("normal_font", body_font)


func _process(delta: float) -> void:
	if not visible or _archive.visible or _closing or controller.menu.visible or _hud_hidden:
		return
	if _travel != 0:
		_travel_wait -= delta
		if _travel_wait <= 0 and not _transitioning:
			_travel_wait = 0.18
			if _travel < 0:
				if not _back_to(_route.size() - 2):
					_stop_modes()
			else:
				_skip_step()
		return
	if _transitioning:
		return
	if _phase == Phase.TYPING:
		_type_progress += _type_speed * delta
		if _type_progress >= float(_total_chars):
			_finish_typing()
		else:
			_text.visible_characters = int(_type_progress)
	elif _phase == Phase.HOLD and _auto_advance and not _transitioning and _choices.get_child_count() == 0:
		_hold_left -= delta
		if _hold_left <= 0.0:
			_next_page()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closing or controller.menu.visible:
		return
	# 小说打开时吞掉所有未被界面处理的输入，避免 pause=false 时误触游戏快捷键
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if _hud_hidden:
			_restore_hud()
			return
		if _archive.visible:
			if event.keycode == KEY_ESCAPE:
				_hide_history()
			return
		if event.keycode == KEY_ESCAPE and _travel != 0:
			_stop_modes()
		elif event.keycode == KEY_ESCAPE:
			request_close()
		elif event.keycode == KEY_H:
			_hide_hud()
		elif event.keycode == KEY_F5:
			_quick(true)
		elif event.keycode == KEY_F9:
			_quick(false)
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			advance()


# ---------------------------------------------------------------- 对外接口

## 开始播放（或替换当前剧本）。
## options:
##   typewriter_speed: float  每秒字数，0 = 直接全部显示
##   auto_advance:     bool   文字显示完后是否自动翻页，默认 true
##   page_hold:        float  自动翻页前停留的秒数，默认 1.6
func show_story(story: VnStory, options: Dictionary = {}) -> void:
	if story == null or story.pages.is_empty():
		push_error("视觉小说：剧本为空，无法播放")
		return

	var was_visible := visible
	_open_serial += 1
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
	_close_tween = null
	_story = story
	_restore_hud()
	_route.clear()
	_travel = 0
	_tools.get_node("Navigation").text = "导航"
	_history.clear()
	_archive.hide()
	_page.show()
	_continuous = false
	_tools.get_node("Auto").text = "自动"
	_tools.get_node("Save").disabled = story.source_path.is_empty()
	_tools.get_node("Load").disabled = false
	_type_speed = maxf(0.0, float(options.get("typewriter_speed", DEFAULT_TYPE_SPEED)))
	_auto_advance = bool(options.get("auto_advance", true))
	_page_hold = maxf(0.0, float(options.get("page_hold", DEFAULT_PAGE_HOLD)))
	_transitioning = false
	_closing = false
	_phase = Phase.IDLE
	_hold_left = 0.0
	_button.disabled = false
	visible = true
	_button.show()
	_button.grab_focus()

	# 复制一份页面样式，改颜色不会影响场景里的原始资源
	var base_style := _page.get_theme_stylebox("panel")
	if base_style is StyleBoxFlat:
		_page_style = (base_style as StyleBoxFlat).duplicate()
	else:
		_page_style = StyleBoxFlat.new()
	_page.add_theme_stylebox_override("panel", _page_style)

	_title_label.text = story.title
	_build_dots()
	_enter_page(0)
	_page.modulate.a = 1.0
	_content.modulate.a = 1.0

	if was_visible:
		_dim.modulate.a = 1.0
		_frame.modulate.a = 1.0
		return

	_dim.modulate.a = 0.0
	_frame.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(_frame, "modulate:a", 1.0, 0.24)


## 玩家点了蓝色按钮（或按了空格 / 回车）。
func advance() -> void:
	if not visible or _closing or _transitioning or _story == null or _archive.visible or controller.menu.visible or _hud_hidden:
		return
	if _travel != 0:
		_stop_modes()
		return

	match _phase:
		Phase.IDLE:
			_start_typing()
		Phase.TYPING:
			_finish_typing()
		Phase.HOLD:
			_next_page()


## 当前正在显示第几页（从 0 开始）。
func current_page() -> int:
	return _page_index


## 关闭并回到游戏（带淡出动画）。
func request_close() -> void:
	if not visible or _closing:
		return
	controller.save_game("resume")
	_closing = true
	_phase = Phase.IDLE
	_button.disabled = true
	var serial := _open_serial
	var tween := create_tween().set_parallel(true)
	_close_tween = tween
	tween.tween_property(_frame, "modulate:a", 0.0, 0.16)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.18)
	await tween.finished
	if serial != _open_serial:   # 关闭动画期间又被重新打开，放弃这次关闭
		return
	_close_tween = null
	visible = false
	_closing = false
	_page.modulate.a = 1.0
	_frame.modulate.a = 1.0
	_content.modulate.a = 1.0
	closed.emit()


# ---------------------------------------------------------------- 内部

func _enter_page(index: int) -> void:
	_page_index = index
	_route.append({"id": _story.pages[index].id, "before": _history.size()})
	_clear_choices()
	_phase = Phase.IDLE
	_hold_left = 0.0
	_text.text = ""
	_text.visible_characters = 0
	_apply_page_style()
	_display_art()
	_refresh_dots()
	_update_button()
	page_changed.emit(_page_index, _story.pages.size())
	_queue_checkpoint()
	if _continuous:
		_start_typing()


func _start_typing() -> void:
	var page: Dictionary = _story.pages[_page_index]
	_text.text = str(page.text)
	_text.visible_characters = 0
	_total_chars = maxi(1, _text.get_total_character_count())
	_type_progress = 0.0
	_phase = Phase.TYPING
	_update_speaker_visibility()
	if _type_speed <= 0.0:
		_finish_typing()
	else:
		_update_button()


func _finish_typing() -> void:
	_text.visible_characters = -1
	_phase = Phase.HOLD
	_hold_left = _page_hold
	var page: Dictionary = _story.pages[_page_index]
	var line: String = page.text
	if not str(page.speaker).is_empty():
		line = "%s　%s" % [page.speaker, line]
	_history.append(line)
	_update_speaker_visibility()
	_update_button()
	_build_choices()
	text_finished.emit(_page_index)
	_queue_checkpoint()
	if _travel > 0 and not page.choices.is_empty():
		_stop_modes()


func _next_page() -> void:
	if _phase == Phase.IDLE or _transitioning or _closing:   # 还没开始读 / 正在翻页
		return
	if not _story.pages[_page_index].choices.is_empty():
		return
	var target: String = _story.pages[_page_index].next
	if not target.is_empty():
		_follow(target)
	elif _page_index + 1 < _story.pages.size():
		_goto_page(_page_index + 1)
	else:
		_finish_story()


func _goto_page(index: int, choice_text := "") -> void:
	_transitioning = true
	_button.disabled = true
	var serial := _open_serial
	var tween := create_tween()
	tween.tween_property(_content, "modulate:a", 0.0, 0.1)
	await tween.finished
	if _closing or serial != _open_serial:
		return

	if not choice_text.is_empty():
		_history.append("› " + choice_text)
	_enter_page(index)

	var tween_in := create_tween()
	tween_in.tween_property(_content, "modulate:a", 1.0, 0.18)
	await tween_in.finished
	if _closing or serial != _open_serial:
		return
	_button.disabled = false
	if _button.visible:
		_button.grab_focus()
	_transitioning = false


func _finish_story() -> void:
	finished.emit()
	request_close()


func _apply_page_style() -> void:
	var page: Dictionary = _story.pages[_page_index]
	var bg: Color = page.color
	var ink := _ink_for(bg)

	_page_style.bg_color = bg
	_page_style.border_color = _with_alpha(ink, 0.22)
	_rule_top.color = _with_alpha(ink, 0.18)
	_rule_bottom.color = _with_alpha(ink, 0.18)
	_index_label.add_theme_color_override("font_color", _with_alpha(ink, 0.62))
	_title_label.add_theme_color_override("font_color", _with_alpha(ink, 0.62))
	_speaker_label.add_theme_color_override("font_color", ink)
	_text.add_theme_color_override("default_color", ink)
	_hint.add_theme_color_override("font_color", _with_alpha(ink, 0.58))
	_idle_hint.add_theme_color_override("font_color", _with_alpha(ink, 0.38))

	_speaker_label.text = str(page.speaker)
	_update_speaker_visibility()

	var color_label := str(page.color_label)
	var suffix := "" if color_label.is_empty() else " · " + color_label
	_index_label.text = "第 %d 页 / 共 %d 页%s" % [_page_index + 1, _story.pages.size(), suffix]


func _build_dots() -> void:
	for child in _dots.get_children():
		child.queue_free()
	_dot_styles.clear()

	for i in _story.pages.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(46, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = _story.pages[i].color
		style.set_corner_radius_all(6)
		dot.add_theme_stylebox_override("panel", style)
		_dots.add_child(dot)
		_dot_styles.append(style)


func _refresh_dots() -> void:
	for i in _dot_styles.size():
		var style := _dot_styles[i]
		var active := i == _page_index
		var color: Color = _story.pages[i].color
		style.bg_color = color if active else _with_alpha(color, 0.38)
		style.set_border_width_all(2)
		style.border_color = _with_alpha(_ink_for(color), 0.95 if active else 0.0)


func _update_button() -> void:
	if _story == null:
		return
	if _idle_hint != null:
		_idle_hint.visible = _phase == Phase.IDLE
	var page: Dictionary = _story.pages[_page_index]
	var is_last_page: bool = page.next == "@end" or (page.next == "" and _page_index == _story.pages.size() - 1)

	match _phase:
		Phase.IDLE:
			_button.text = "阅读 ▶"
			_hint.text = "点蓝色按钮，这一页的文字会逐字出现 · Esc 关闭"
		Phase.TYPING:
			_button.text = "显示全部"
			_hint.text = "点蓝色按钮立刻显示全部文字 · 空格 / 回车 也可以"
		Phase.HOLD:
			_button.text = "结束 ✓" if is_last_page else "下一页 ▶"
			if _auto_advance:
				if is_last_page:
					_hint.text = "文字读完了，马上结束…点按钮可立即关闭"
				else:
					_hint.text = "文字读完了，马上自动翻页…点按钮可立即翻页"
			elif is_last_page:
				_hint.text = "点蓝色按钮结束剧情，回到游戏"
			else:
				_hint.text = "点蓝色按钮翻到下一页 · 空格 / 回车 也可以 · Esc 关闭"


func _update_speaker_visibility() -> void:
	if _story == null:
		return
	var page: Dictionary = _story.pages[_page_index]
	var has_speaker := not str(page.speaker).strip_edges().is_empty()
	_speaker_label.visible = has_speaker and _phase != Phase.IDLE


func _display_art() -> void:
	var page: Dictionary = _story.pages[_page_index]
	for pair in [[_backdrop, page.background], [_portrait, page.portrait]]:
		var view: TextureRect = pair[0]
		var path: String = pair[1]
		view.texture = null
		if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
			view.texture = load(path) as Texture2D
		view.visible = view.texture != null
	var illustrated := _backdrop.visible or _portrait.visible
	_content.anchor_top = 0.55 if illustrated else 0.14
	_content.anchor_bottom = 0.77
	_content.offset_top = 10
	_content.offset_bottom = 0
	_content.anchor_right = 0.57 if not page.choices.is_empty() else 1.0
	_speaker_label.add_theme_font_size_override("font_size", 36 if illustrated else 52)
	_text.add_theme_font_size_override("normal_font_size", 40 if illustrated else 60)
	_index_label.visible = not illustrated
	_title_label.visible = not illustrated
	_rule_top.visible = not illustrated


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	_choices.get_parent().hide()
	_button.show()


func _build_choices() -> void:
	_clear_choices()
	for choice in _story.pages[_page_index].choices:
		var option := Button.new()
		option.text = choice.text
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.pressed.connect(_select_choice.bind(choice))
		_choices.add_child(option)
	if _choices.get_child_count() > 0:
		_choices.get_parent().show()
		_button.hide()
		_hint.text = "请选择路线"
		_choices.get_child(0).grab_focus()


func _select_choice(choice: Dictionary) -> void:
	if _phase != Phase.HOLD or _transitioning or _closing or _archive.visible:
		return
	if _travel != 0:
		_stop_modes()
	if choice.next == "@end":
		_history.append("› " + str(choice.text))
		_finish_story()
	else:
		_goto_page(_story.page_indices[choice.next], choice.text)


func _follow(target: String) -> void:
	if target == "@end":
		_finish_story()
	else:
		_goto_page(_story.page_indices[target])


func _toggle_auto() -> void:
	if _closing or _transitioning:
		return
	_travel = 0
	_tools.get_node("Navigation").text = "导航"
	_continuous = not _continuous
	_auto_advance = _continuous
	_tools.get_node("Auto").text = "自动 ✓" if _continuous else "自动"
	_hold_left = _page_hold
	if _continuous and _phase == Phase.IDLE and not _transitioning:
		_start_typing()
	else:
		_update_button()
	if _choices.get_child_count() > 0:
		_hint.text = "请选择路线"


func _show_history() -> void:
	if _transitioning or _closing:
		return
	_page.hide()
	_archive.show()
	var transcript: RichTextLabel = _archive.get_node("Body/Log")
	transcript.text = "\n\n".join(_history) if not _history.is_empty() else "尚无已读对白"
	_archive.get_node("Body/Back").grab_focus()


func _hide_history() -> void:
	_archive.hide()
	_page.show()
	_tools.get_node("History").grab_focus()


func _queue_checkpoint() -> void:
	if not _checkpoint_pending and not _story.source_path.is_empty():
		_checkpoint_pending = true
		_flush_checkpoint.call_deferred()


func _flush_checkpoint() -> void:
	_checkpoint_pending = false
	if visible and not _closing and controller.is_open:
		controller.save_game("resume")


func snapshot() -> Dictionary:
	if _story == null or _story.source_path.is_empty() or _route.is_empty():
		return {}
	return {"version": 2, "story": _story.source_path, "revision": _story.revision,
		"title": _story.title, "page": _story.pages[_page_index].id,
		"read": _phase == Phase.HOLD, "history": _history.duplicate(), "route": _route.duplicate(true)}


func restore(state: Dictionary) -> void:
	_stop_modes()
	_route.clear()
	_history.clear()
	_enter_page(_story.page_indices[state.page])
	if state.read:
		_reveal()
	_history.assign(state.history)
	if state.has("route"):
		_route = state.route.duplicate(true)
	else:
		# 旧存档仅记录文本；从能确定的当前页重新建立可回退路径。
		_route[0].before = maxi(0, _history.size() - int(state.read))
	_hint.text = "进度已恢复"


func apply_preference(key: String, value: float) -> void:
	if key == "speed":
		_type_speed = value
		if value == 0 and _phase == Phase.TYPING:
			_finish_typing()
	elif key == "delay":
		_page_hold = value
		_hold_left = value


func visited_ids() -> Array:
	return _route.map(func(step): return step.id)


func _quick(saving: bool) -> void:
	if _transitioning or _closing:
		return
	var ok: bool = controller.quick_save() if saving else controller.quick_load()
	if saving:
		_hint.text = "已快速存档" if ok else "快存失败"
	else:
		_hint.text = "已快速读档" if ok else "没有可用的快速存档"


func _reveal() -> void:
	if _phase != Phase.HOLD:
		_text.text = _story.pages[_page_index].text
		_finish_typing()


func _stop_modes() -> void:
	_travel = 0
	_continuous = false
	_auto_advance = false
	_tools.get_node("Auto").text = "自动"
	_tools.get_node("Navigation").text = "导航"


func _navigation_menu() -> void:
	if _closing or _transitioning:
		return
	if _travel != 0:
		_stop_modes()
		return
	controller.menu.begin("navigation", "阅读导航")
	var targets := {"上一句": "line", "上一个选项": "prev_choice", "上一个场景": "prev_scene",
		"快退": "rewind", "快进": "forward", "下一个场景": "next_scene", "下一个选项": "next_choice"}
	for label in targets:
		controller.menu.action(label, navigate.bind(targets[label]))


func navigate(command: String) -> void:
	if _closing or _transitioning:
		return
	controller.menu.close()
	_stop_modes()
	match command:
		"line":
			if not _back_to(_route.size() - 2):
				_hint.text = "已到第一句"
		"prev_choice", "prev_scene":
			var previous := _previous_stop(command == "prev_choice")
			if not _back_to(previous):
				_hint.text = "前面没有对应的节点"
		"rewind", "forward":
			_travel = -1 if command == "rewind" else 1
			_travel_wait = 0
			_tools.get_node("Navigation").text = "停止快退" if _travel < 0 else "停止快进"
		"next_scene", "next_choice":
			_seek_forward(command == "next_choice")


func _previous_stop(choice: bool) -> int:
	var scene := _story.scene_key(_page_index)
	for i in range(_route.size() - 2, -1, -1):
		var index: int = _story.page_indices[_route[i].id]
		if choice and not _story.pages[index].choices.is_empty():
			return i
		if not choice and _story.scene_key(index) != scene:
			var target := i
			while target > 0 and _story.scene_key(_story.page_indices[_route[target - 1].id]) == _story.scene_key(index):
				target -= 1
			return target
	return -1


func _back_to(step: int) -> bool:
	if step < 0 or step >= _route.size():
		return false
	var entry: Dictionary = _route[step]
	_route.resize(step)
	_history.resize(int(entry.before))
	_enter_page(_story.page_indices[entry.id])
	_reveal()
	return true


func _skip_step() -> bool:
	_reveal()
	if not _story.pages[_page_index].choices.is_empty():
		_stop_modes()
		return false
	var next := _story.next_id(_page_index)
	if next == "@end":
		_stop_modes()
		_hint.text = "已到最后一句"
		return false
	_enter_page(_story.page_indices[next])
	_reveal()
	return true


func _seek_forward(choice: bool) -> void:
	var scene := _story.scene_key(_page_index)
	var seen := {}
	while not seen.has(_page_index):
		seen[_page_index] = true
		if not _skip_step():
			return
		if not _story.pages[_page_index].choices.is_empty() or (not choice and _story.scene_key(_page_index) != scene):
			return
	_hint.text = "当前路线循环，已停止跳转"


func _hide_hud() -> void:
	if _closing or _transitioning:
		return
	_hud_hidden = true
	_hud_visibility.clear()
	for child in _page.get_children():
		if child is Control and child != _backdrop and child != _portrait:
			_hud_visibility[child] = child.visible
			child.hide()


func _restore_hud() -> void:
	if not _hud_hidden:
		return
	for child in _hud_visibility:
		child.visible = _hud_visibility[child]
	_hud_visibility.clear()
	_hud_hidden = false
	_tools.get_node("HideHud").grab_focus()


func _input(event: InputEvent) -> void:
	if controller.menu.visible:
		return
	if visible and _hud_hidden:
		get_viewport().set_input_as_handled()
		if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.pressed:
			_restore_hud()


func _ink_for(bg: Color) -> Color:
	var luma := 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
	return DARK_INK if luma > 0.6 else LIGHT_INK


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
