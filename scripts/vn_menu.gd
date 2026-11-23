extends CanvasLayer

signal dismissed
var controller
const PAPER := Color("e7e5dc")
const INK := Color("17232d")
const ACCENT := Color("5da39a")
var shade := ColorRect.new()
var body := VBoxContainer.new()
var heading := Label.new()
var status := Label.new()
var back := Button.new()
var return_to := Callable()
var kind := ""
var last_focus: WeakRef
var focus_scope: Array[Control] = []

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("0b1723e8")
	var surface := PanelContainer.new()
	shade.add_child(surface)
	surface.add_theme_stylebox_override("panel", box(INK, Color("52626a"), 12))
	var theme := Theme.new()
	theme.default_font_size = 24
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_stylebox("normal", "Button", box(Color("263541"), Color("40535b"), 7))
	theme.set_stylebox("hover", "Button", box(Color("304b52"), ACCENT, 7))
	theme.set_stylebox("pressed", "Button", box(Color("20383c"), ACCENT, 7))
	var focus := box(Color.TRANSPARENT, ACCENT, 7)
	focus.draw_center = false
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	surface.theme = theme
	surface.anchor_left = 0.12
	surface.anchor_right = 0.88
	surface.anchor_top = 0.08
	surface.anchor_bottom = 0.92
	var margin := MarginContainer.new()
	surface.add_child(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	var column := VBoxContainer.new()
	margin.add_child(column)
	column.add_theme_constant_override("separation", 14)
	column.add_child(heading)
	heading.add_theme_font_size_override("font_size", 38)
	var scroll := ScrollContainer.new()
	column.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(status)
	column.add_child(back)
	back.text = "返回"
	back.pressed.connect(go_back)
	hide()

func box(fill: Color, stroke: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = stroke
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func begin(screen: String, title: String, parent_menu := Callable()) -> void:
	if not visible:
		var focus := get_viewport().gui_get_focus_owner()
		last_focus = weakref(focus) if focus != null else null
	kind = screen
	return_to = parent_menu
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	heading.text = title
	status.text = ""
	show()
	back.grab_focus()

func action(label: String, handler: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 25)
	body.add_child(button)
	button.disabled = not enabled
	button.pressed.connect(handler)
	if body.get_child_count() == 1 and enabled:
		button.grab_focus()
	return button

func close() -> void:
	if not visible:
		return
	hide()
	kind = ""
	if last_focus != null:
		var focus = last_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	dismissed.emit()

func go_back() -> void:
	if return_to.is_valid():
		return_to.call()
	else:
		close()

func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		var controls := body.find_children("*", "Control", true, false)
		focus_scope.clear()
		for item in controls:
			if item.focus_mode == Control.FOCUS_ALL and item.is_visible_in_tree() and not (item is BaseButton and item.disabled):
				focus_scope.append(item)
		focus_scope.append(back)
		var index := focus_scope.find(get_viewport().gui_get_focus_owner())
		focus_scope[posmod(index + (-1 if event.shift_pressed else 1), focus_scope.size())].grab_focus()
		get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		go_back()

func slots(saving: bool, parent_menu: Callable) -> void:
	begin("save" if saving else "load", "保存进度" if saving else "读取进度", parent_menu)
	var slots_available := ["1", "2", "3"] if saving else ["1", "2", "3", "quick", "resume"]
	for slot in slots_available:
		var state: Dictionary = controller.storage.read_slot(slot)
		var name_text: String = {"quick": "快速存档", "resume": "继续进度"}.get(slot, "存档 " + slot)
		var occupied := FileAccess.file_exists(controller.storage.slot_path(slot))
		var summary := "空"
		if occupied:
			summary = "%s · %s" % [str(state.get("title", str(state.get("story", "")).get_file())), str(state.get("page", "?"))] if state.has("page") else "存档损坏"
		action(name_text + "　" + summary, _slot_action.bind(slot, saving), saving or occupied)

func _slot_action(slot: String, saving: bool) -> void:
	var ok: bool = controller.save_game(slot) if saving else controller.load_game(slot)
	if ok:
		close()
	else:
		status.text = "写入失败" if saving else "读档失败，请检查剧本版本或存档内容"

func settings(volume_only: bool, parent_menu: Callable) -> void:
	begin("settings", "音量" if volume_only else "系统设置", parent_menu)
	if not volume_only:
		_slider("speed", "文字速度（字／秒，0 为快显）", 0, 100, 1)
		_slider("delay", "自动翻页等待（秒）", 0.2, 5, 0.1)
	_slider("volume", "主音量（%）", 0, 100, 1)

func _slider(key: String, label: String, minimum: float, maximum: float, step: float) -> void:
	var caption := Label.new()
	var slider := HSlider.new()
	body.add_child(caption)
	body.add_child(slider)
	slider.custom_minimum_size.y = 44
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	var scale_factor := 100.0 if key == "volume" else 1.0
	slider.value = controller.storage.preferences[key] * scale_factor
	caption.text = "%s　%s" % [label, slider.value]
	slider.value_changed.connect(func(value: float):
		caption.text = "%s　%s" % [label, value]
		if not controller.set_preference(key, value / scale_factor):
			status.text = "设置保存失败")

func flow(story: VnStory, current: String, visited: Array, parent_menu: Callable) -> void:
	begin("flow", "流程图 · " + story.title, parent_menu)
	var graph := GraphEdit.new()
	graph.custom_minimum_size.y = 520
	graph.minimap_enabled = false
	body.add_child(graph)
	var edges: Array = []
	var adjacency: Array = []
	for i in story.pages.size():
		var page: Dictionary = story.pages[i]
		var exits: Array = page.choices.duplicate()
		if exits.is_empty():
			exits.append({"text": "继续", "next": story.next_id(i)})
		adjacency.append(exits)
	# 按离起点的最短距离分列，分支并排，循环边仍可连接。
	var depth := {0: 0}
	var queue := [0]
	var cursor := 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		for edge in adjacency[index]:
			if edge.next != "@end":
				var dest: int = story.page_indices[edge.next]
				if not depth.has(dest):
					depth[dest] = depth[index] + 1
					queue.append(dest)
	var rows := {}
	for i in story.pages.size():
		var page: Dictionary = story.pages[i]
		var node := GraphNode.new()
		node.name = "Page%d" % i
		var mark := "● " if current == page.id else ("✓ " if page.id in visited else "")
		node.title = mark + str(page.id)
		var col: int = depth.get(i, 0)
		node.position_offset = Vector2(28 + col * 260, 24 + int(rows.get(col, 0)))
		rows[col] = int(rows.get(col, 0)) + 90 + 42 * adjacency[i].size()
		graph.add_child(node)
		for j in adjacency[i].size():
			var edge: Dictionary = adjacency[i][j]
			var line := Label.new()
			line.text = edge.text if edge.next != "@end" else str(edge.text) + " · 结束"
			node.add_child(line)
			node.set_slot(j, j == 0, 0, Color.WHITE, edge.next != "@end", 0, Color.SKY_BLUE)
			if edge.next != "@end":
				edges.append([node.name, node.get_output_port_count() - 1, "Page%d" % story.page_indices[edge.next]])
	for edge in edges:
		graph.connect_node(edge[0], edge[1], edge[2], 0)
