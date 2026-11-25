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
const FX_SMOKE := preload("res://assets/fx/smoke.png")
## 每种船一张图。
const SHIP_TEXTURES := {
	Type.SENTRY: preload("res://assets/ships/sentry.png"),
	Type.ROCKET: preload("res://assets/ships/rocket.png"),
	Type.CANNON: preload("res://assets/ships/cannon.png"),
}
## 船在棋盘上的显示宽度（格）。
const SHIP_WIDTHS := {
	Type.SENTRY: 1.55,
	Type.ROCKET: 1.85,
	Type.CANNON: 1.95,
}
const STEP_TRAVEL_SPEED := 4.5   # 单位/秒，逐格移动的行进速度
const STEP_PAUSE := 0.0          # 不停顿，连续滑行

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
var _ship: Sprite2D
var _tier := 4
var _bob_time := 0.0
## 被拖动时敌人不索敌、不攻击。
var being_dragged := false
## 放置时的虚影：不进 units 组，敌人不会索敌它。
var is_ghost := false


func _ready() -> void:
	if not is_ghost:
		add_to_group("units")
	_ship = Sprite2D.new()
	_ship.centered = true
	_ship.position = Vector2(0.0, -0.05)
	add_child(_ship)
	_refresh_ship(true)


func setup(type: Type) -> void:
	unit_type = type
	stats = STATS[type]
	cost = stats.cost
	max_hp = stats.hp
	hp = max_hp
	_refresh_ship(true)
	queue_redraw()


## 血量挡位：4 = 满血，1 = 快沉了。
func _tier_for_hp() -> int:
	if max_hp <= 0.0:
		return 1
	return clampi(ceili(hp / max_hp * 4.0), 1, 4)


## 换上对应的船图，按格宽缩放。
func _refresh_ship(force := false) -> void:
	if _ship == null:
		return
	var tier := _tier_for_hp()
	if not force and tier == _tier and _ship.texture != null:
		return
	_tier = tier
	var texture: Texture2D = SHIP_TEXTURES.get(unit_type)
	if texture == null:
		return
	_ship.texture = texture
	var width: float = SHIP_WIDTHS.get(unit_type, 1.6)
	var factor := width / maxf(1.0, float(texture.get_width()))
	_ship.scale = Vector2(factor, factor)


## 攻击力随挡位变化：1 档 = 50%，4 档 = 100%。
func _damage_multiplier() -> float:
	return 0.5 + 0.5 * float(_tier - 1) / 3.0


## 维修：返回实际回复量。
func repair(amount: float) -> float:
	var missing := max_hp - hp
	if missing <= 0.0:
		return 0.0
	var healed := minf(amount, missing)
	hp += healed
	_refresh_ship(true)
	return healed


func _process(delta: float) -> void:
	if _dead:
		return
	if being_dragged:
		modulate = Color(1, 1, 1, 0.45)
	_bob_time += delta
	if _ship != null:
		_ship.position.y = -0.05 + sin(_bob_time * 2.2) * 0.02
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
		projectile.setup_rocket(target, stats.attack * _damage_multiplier(), stats.burn_dps, stats.burn_time)
	else:
		projectile.setup_shell(target, stats.attack * _damage_multiplier(), stats.aoe_radius, stats.instakill)
	get_parent().add_child(projectile)
	projectile.position = position
	projectile.rotation = angle


func take_damage(amount: float) -> void:
	_apply_damage(amount, true)


func _apply_damage(amount: float, flash: bool) -> void:
	if _dead or being_dragged:
		return
	hp = maxf(0.0, hp - amount)
	_refresh_ship()
	if flash and not being_dragged:
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
	# 沉船反馈：墨烟 + 缩小旋转淡出
	Fx.play(get_parent(), position, FX_SMOKE, 2.2, 0.5, 0.6)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.7, 0.7), 0.6)
	tween.tween_property(self, "rotation", 0.22, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(queue_free)


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

	if unit_type == Type.SENTRY:
		draw_circle(Vector2.ZERO, stats.range, Color(color.r, color.g, color.b, 0.06))
		draw_arc(Vector2.ZERO, stats.range, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.3), 0.04, true)
