class_name Unit
extends Node2D

## 三种船（占位图：三个颜色的方块）。
##   哨船：不攻击，范围内减速敌人（牵制），血最厚。
##   火箭船：射速快、单体伤害，命中后持续燃烧。
##   炮船：射速慢、范围伤害，有概率一击必杀。

signal died(unit: Unit)
signal move_finished

enum Type { SENTRY, ROCKET, CANNON }

const STATS := {
	Type.SENTRY: {
		"name": "哨船",
		"color": Color(0.28, 0.55, 0.88),
		"cost": 15.0,
		"hp": 190.0,
		"range": 2.6,
		"attack": 0.0,
		"interval": 0.0,
		"slow": 0.55,
		"desc": "不攻击 · 范围内敌人减速 45%",
	},
	Type.ROCKET: {
		"name": "火箭船",
		"color": Color(0.92, 0.52, 0.26),
		"cost": 25.0,
		"hp": 90.0,
		"range": 3.6,
		"attack": 8.0,
		"interval": 0.5,
		"burn_dps": 3.0,
		"burn_time": 3.0,
		"desc": "单体 · 命中后燃烧 3 秒",
	},
	Type.CANNON: {
		"name": "炮船",
		"color": Color(0.58, 0.47, 0.78),
		"cost": 35.0,
		"hp": 120.0,
		"range": 4.4,
		"attack": 18.0,
		"interval": 1.7,
		"aoe_radius": 1.7,
		"instakill": 0.12,
		"desc": "范围伤害 · 12% 一击必杀",
	},
}

const PROJECTILE_SCENE := preload("res://scenes/entities/projectile.tscn")
const SQUARE_SIZE := 0.92
const STEP_TRAVEL_SPEED := 4.5   # 单位/秒，逐格移动的行进速度
const STEP_PAUSE := 0.4          # 每走到一格停多久
const BAR_WIDTH := 0.86
const BAR_HEIGHT := 0.10
const BAR_TOP := -0.64

var unit_type := Type.SENTRY
var stats: Dictionary = {}
var cost := 0.0
var max_hp := 100.0
var hp := 100.0

var _cooldown := 0.0
var _moving := false
var _stepping := false
var _step_points := PackedVector2Array()
var _step_index := 0
var _step_wait := 0.0
var _step_speed := STEP_TRAVEL_SPEED
var _held := false
var _dead := false
var _flash_time := 0.0
var _stun_time := 0.0
var _burn_time := 0.0
var _burn_dps := 0.0


func _ready() -> void:
	add_to_group("units")


func setup(type: Type) -> void:
	unit_type = type
	stats = STATS[type]
	cost = stats.cost
	max_hp = stats.hp
	hp = max_hp
	queue_redraw()


func _process(delta: float) -> void:
	if _dead:
		return
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			modulate = Color.WHITE
	if _burn_time > 0.0:
		_burn_time -= delta
		_apply_damage(_burn_dps * delta, false)
		if _dead:
			return
	if _stun_time > 0.0:
		_stun_time -= delta
		return
	if _stepping:
		# 逐格移动中也会走到下面的攻击逻辑：移动时照样能开火。
		_advance_step(delta)
	elif _moving or _held:
		return

	if unit_type == Type.SENTRY:
		_apply_slow_aura()
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		var target = _find_target()
		if target != null:
			_fire(target)


func _apply_slow_aura() -> void:
	var radius: float = stats.range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if position.distance_to(enemy.position) <= radius:
			enemy.apply_slow(stats.slow, 0.15)


func _find_target():
	var best = null
	var best_distance: float = stats.range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance: float = position.distance_to(enemy.position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


func _fire(target) -> void:
	_cooldown = stats.interval
	var angle: float = (target.position - position).angle()
	var projectile = PROJECTILE_SCENE.instantiate()
	if unit_type == Type.ROCKET:
		projectile.setup_rocket(target, stats.attack, stats.burn_dps, stats.burn_time)
	else:
		projectile.setup_shell(target, stats.attack, stats.aoe_radius, stats.instakill)
	get_parent().add_child(projectile)
	projectile.position = position
	projectile.rotation = angle


func take_damage(amount: float) -> void:
	_apply_damage(amount, true)


func _apply_damage(amount: float, flash: bool) -> void:
	if _dead:
		return
	hp = maxf(0.0, hp - amount)
	if flash:
		_flash_time = 0.10
		modulate = Color(1.6, 1.6, 1.6)
	queue_redraw()
	if hp <= 0.0:
		_die()


## 被倭刀船眩晕：一定时间内不攻击、不开光环。
func stun(duration: float) -> void:
	_stun_time = maxf(_stun_time, duration)


## 持续伤害（倭刀船 / 炸弹船点燃）。
func apply_burn(dps: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)


func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("units")
	died.emit(self)
	queue_free()


## 平移到新位置；途中不能开火。
func move_to(target_position: Vector2, duration: float) -> void:
	_moving = true
	var tween := create_tween()
	tween.tween_property(self, "position", target_position, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_on_move_finished)


## 沿一串格子中心逐格移动：走一格 → 停 STEP_PAUSE 秒 → 走下一格。
func move_through(points: PackedVector2Array, speed := STEP_TRAVEL_SPEED) -> void:
	if points.is_empty():
		return
	_stepping = true
	_moving = false
	_step_points = points
	_step_index = 0
	_step_wait = 0.0
	_step_speed = speed


func _advance_step(delta: float) -> void:
	if _step_wait > 0.0:
		_step_wait -= delta
		return
	if _step_index >= _step_points.size():
		_finish_step()
		return
	var target := _step_points[_step_index]
	var to_target := target - position
	var step := _step_speed * delta
	if to_target.length() <= step:
		position = target
		_step_index += 1
		if _step_index >= _step_points.size():
			_finish_step()
		else:
			_step_wait = STEP_PAUSE
	else:
		position += to_target.normalized() * step


func _finish_step() -> void:
	_stepping = false
	_step_points = PackedVector2Array()
	_step_index = 0
	_step_wait = 0.0
	move_finished.emit()


func is_moving() -> bool:
	return _moving or _stepping


func _on_move_finished() -> void:
	_moving = false
	move_finished.emit()


## 被拖动 / 从基地滑出期间抓住单位：不找目标、不开火。
func set_held(value: bool) -> void:
	_held = value


func _draw() -> void:
	if _dead:
		return
	var color: Color = stats.color
	var half := SQUARE_SIZE * 0.5

	if unit_type == Type.SENTRY:
		draw_circle(Vector2.ZERO, stats.range, Color(color.r, color.g, color.b, 0.07))
		draw_arc(Vector2.ZERO, stats.range, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.35), 0.04, true)

	draw_rect(Rect2(-half, -half, SQUARE_SIZE, SQUARE_SIZE), color)
	draw_rect(Rect2(-half, -half, SQUARE_SIZE, SQUARE_SIZE), color.darkened(0.45), false, 0.06)

	if hp < max_hp:
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-BAR_WIDTH * 0.5, BAR_TOP, BAR_WIDTH, BAR_HEIGHT), Color(0.0, 0.0, 0.0, 0.45))
		draw_rect(Rect2(-BAR_WIDTH * 0.5, BAR_TOP, BAR_WIDTH * ratio, BAR_HEIGHT), Color(0.35, 0.82, 0.38))
