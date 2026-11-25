class_name Enemy
extends Node2D

## 敌人：沿格子中心连成的折线前进，有血量；会被减速、燃烧，也会伤害附近的单位。
##
## 四种类型：
##   倭寇小船 —— 普通敌人，近战攻击附近单位。
##   倭刀船   —— 移动快，近战命中会眩晕目标并造成持续伤害。
##   冲锋船   —— 不攻击，给附近敌人加移速和攻速。
##   炸弹船   —— 血厚、移动快，碰到我方单位就自爆，范围伤害 + 点燃。

signal reached_base(enemy: Enemy)
signal died(enemy: Enemy)

const HexBoardClass := preload("res://scripts/hex_board.gd")
const BOOM_SCENE := preload("res://scenes/entities/boom.tscn")
const FX_SMOKE := preload("res://assets/fx/smoke.png")
const FX_BURST := preload("res://assets/fx/burst.png")

enum Type { SMALL, SWORD, CHARGE, BOMB }

const STATS := {
	Type.SMALL: {
		"name": "倭寇小船",
		"hp": 40.0,
		"speed": 1.00,
		"damage": 2.0,
		"interval": 1.0,
		"range": 2.1,
		"color": Color(1.0, 1.0, 1.0),
		"scale": 1.0,
	},
	Type.SWORD: {
		"name": "倭刀船",
		"hp": 55.0,
		"speed": 1.50,
		"damage": 4.0,
		"interval": 1.0,
		"range": 2.1,
		"stun": 0.7,
		"bleed_dps": 2.0,
		"bleed_time": 3.0,
		"color": Color(0.95, 0.45, 0.42),
		"scale": 1.1,
	},
	Type.CHARGE: {
		"name": "冲锋船",
		"hp": 70.0,
		"speed": 1.15,
		"damage": 0.0,
		"interval": 1.0,
		"range": 0.0,
		"buff_radius": 3.2,
		"buff_move": 1.30,
		"buff_attack": 1.30,
		"color": Color(1.0, 0.76, 0.36),
		"scale": 1.15,
	},
	Type.BOMB: {
		"name": "炸弹船",
		"hp": 90.0,
		"speed": 1.55,
		"damage": 0.0,
		"interval": 1.0,
		"range": 1.5,
		"explode_range": 1.5,
		"explode_damage": 24.0,
		"explode_radius": 1.4,
		"ignite_dps": 2.0,
		"ignite_time": 3.0,
		"color": Color(0.45, 0.40, 0.52),
		"scale": 1.3,
	},
}

const BAR_WIDTH := 0.82
const BAR_HEIGHT := 0.10
const BAR_TOP := -0.64
## 每走到一格后停下等多久，再走下一格。
const PAUSE_PER_CELL := 0.0

var enemy_type := Type.SMALL
var display_name := "倭寇小船"
var speed_cells := 1.0
var speed := 2.6                    # 单位 / 秒（1 单位 = 六边形半径）
var max_hp := 40.0
var hp := 40.0
var attack_damage := 2.0
var attack_interval := 1.0
var attack_range := 2.1

var stun_time := 0.0
var bleed_dps := 0.0
var bleed_time := 0.0
var explode_range := 0.0
var explode_damage := 0.0
var explode_radius := 0.0
var ignite_dps := 0.0
var ignite_time := 0.0
var buff_radius := 0.0
var buff_move := 1.0
var buff_attack := 1.0

var counts_as_kill := true
var waypoint := Vector2i(-1, -1)

var _points := PackedVector2Array()
var _index := 0
var _done := false
var _dead := false
var _flash_time := 0.0
var _burn_time := 0.0
var _burn_dps := 0.0
var _slow_factor := 1.0
var _slow_time := 0.0
var _attack_timer := 0.0
## 正在追我方单位（全图索敌）。
var chasing := false
var chase_cell := Vector2i(-1, -1)
var _wait_time := 0.0
var _jitter := 0.0
var _buff_move_now := 1.0
var _buff_attack_now := 1.0
var _buff_time := 0.0
var _tint := Color.WHITE
var _size := 1.0
var _base_sprite_scale := Vector2.ONE

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("enemies")
	_base_sprite_scale = _sprite.scale


## 按类型设置血量、速度、攻击和特性。要在 add_child 之前调用。
func configure(type: Type) -> void:
	enemy_type = type
	var data: Dictionary = STATS[type]
	display_name = data.name
	speed_cells = data.speed
	max_hp = data.hp
	hp = max_hp
	attack_damage = data.get("damage", 0.0)
	attack_interval = data.get("interval", 1.0)
	attack_range = data.get("range", 2.1)
	stun_time = data.get("stun", 0.0)
	bleed_dps = data.get("bleed_dps", 0.0)
	bleed_time = data.get("bleed_time", 0.0)
	explode_range = data.get("explode_range", 0.0)
	explode_damage = data.get("explode_damage", 0.0)
	explode_radius = data.get("explode_radius", 0.0)
	ignite_dps = data.get("ignite_dps", 0.0)
	ignite_time = data.get("ignite_time", 0.0)
	buff_radius = data.get("buff_radius", 0.0)
	buff_move = data.get("buff_move", 1.0)
	buff_attack = data.get("buff_attack", 1.0)
	_tint = data.get("color", Color.WHITE)
	_size = data.get("scale", 1.0)
	queue_redraw()


func set_max_hp(value: float) -> void:
	max_hp = maxf(1.0, value)
	hp = max_hp
	queue_redraw()


## points 是格子中心的序列（从出生点一直到基地）。
func setup(points: PackedVector2Array, cells_per_second: float) -> void:
	_jitter = randf_range(-0.24, 0.24)
	_points = _with_jitter(points)
	speed = cells_per_second * HexBoardClass.HEX_WIDTH   # 一格 ≈ 1.732 个单位
	_index = 0
	if _sprite != null:
		_sprite.modulate = _tint
		_sprite.scale = _base_sprite_scale * _size
	if _points.is_empty():
		_arrive()
		return
	position = _points[0]
	if _points.size() > 1:
		_index = 1
		_sprite.rotation = (_points[1] - _points[0]).angle()
	else:
		_arrive()


## 棋盘变化（放塔 / 拆塔）后重新给一条路。cells 的第一格是它当前所在格。
func follow_cells(cells: Array[Vector2i], board: HexBoardClass) -> void:
	var points := PackedVector2Array()
	for cell in cells:
		points.append(board.cell_center(cell))
	if points.size() > 1:
		points.remove_at(0)
	_points = _with_jitter(points)
	_index = 0
	if _points.is_empty():
		_arrive()


## 给路线加一点左右偏移，让每个敌人的走线不完全重合。
func _with_jitter(points: PackedVector2Array) -> PackedVector2Array:
	if _jitter == 0.0 or points.is_empty():
		return points
	var result := points.duplicate()
	for i in result.size():
		var tangent: Vector2
		if i == 0 and result.size() > 1:
			tangent = result[1] - result[0]
		elif i == result.size() - 1:
			tangent = result[i] - result[i - 1]
		else:
			tangent = result[i + 1] - result[i - 1]
		if tangent.length() > 0.01:
			result[i] += tangent.normalized().orthogonal() * _jitter
	return result


func apply_burn(dps: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)


func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, factor)
	_slow_time = maxf(_slow_time, duration)


## 冲锋船给的光环：移动 / 攻击加速。
func apply_buff(move_mult: float, attack_mult: float, duration: float) -> void:
	_buff_move_now = maxf(_buff_move_now, move_mult)
	_buff_attack_now = maxf(_buff_attack_now, attack_mult)
	_buff_time = maxf(_buff_time, duration)


func take_damage(amount: float) -> void:
	_apply_damage(amount, true)


func _apply_damage(amount: float, flash: bool) -> void:
	if _dead or _done:
		return
	hp = maxf(0.0, hp - amount)
	if flash:
		_flash_time = 0.12
		modulate = Color(1.7, 1.7, 1.7)
	queue_redraw()
	if hp <= 0.0:
		_die()


func _process(delta: float) -> void:
	if _dead:
		return
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			modulate = Color.WHITE
	if _done:
		return

	if _burn_time > 0.0:
		_burn_time -= delta
		_apply_damage(_burn_dps * delta, false)
		if _dead:
			return

	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0

	if _buff_time > 0.0:
		_buff_time -= delta
		if _buff_time <= 0.0:
			_buff_move_now = 1.0
			_buff_attack_now = 1.0

	# 冲锋船：给附近的敌人加速，自己不攻击。
	if enemy_type == Type.CHARGE:
		_buff_nearby()
		_walk(delta)
		return

	# 炸弹船：靠近我方单位就自爆。
	if enemy_type == Type.BOMB:
		if _find_unit(explode_range) != null:
			_explode()
			return
		_walk(delta)
		return

	# 其余敌人：附近有船就停下来先把它打掉。
	var victim = _find_unit(attack_range)
	if victim != null:
		_sprite.rotation = (victim.position - position).angle()
		_attack_timer -= delta * _attack_speed()
		if _attack_timer <= 0.0:
			_attack_timer = attack_interval
			_attack(victim)
		return

	_walk(delta)


func _walk(delta: float) -> void:
	# 走一格 → 停一会儿 → 再走下一格。
	if _wait_time > 0.0:
		_wait_time -= delta
		return
	if _points.is_empty():
		return
	var slow_scale := _slow_factor if _slow_time > 0.0 else 1.0
	var buff := _buff_move_now if _buff_time > 0.0 else 1.0
	var target := _points[_index]
	var to_target := target - position
	var step := speed * slow_scale * buff * delta
	if to_target.length() <= step:
		position = target
		_index += 1
		if _index >= _points.size():
			_arrive()
		else:
			_wait_time = PAUSE_PER_CELL
	else:
		position += to_target.normalized() * step
		_sprite.rotation = to_target.angle()


func _attack_speed() -> float:
	return _buff_attack_now if _buff_time > 0.0 else 1.0


func _attack(victim) -> void:
	victim.take_damage(attack_damage)
	if stun_time > 0.0:
		victim.stun(stun_time)
	if bleed_dps > 0.0:
		victim.apply_burn(bleed_dps, bleed_time)


func _buff_nearby() -> void:
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		if position.distance_to(other.position) <= buff_radius:
			other.apply_buff(buff_move, buff_attack, 0.25)


func _explode() -> void:
	counts_as_kill = false
	var center := position
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.being_dragged or unit.is_ghost:
			continue
		if unit.position.distance_to(center) <= explode_radius:
			unit.take_damage(explode_damage)
			if ignite_dps > 0.0:
				unit.apply_burn(ignite_dps, ignite_time)
	var boom = BOOM_SCENE.instantiate()
	boom.radius = explode_radius
	get_parent().add_child(boom)
	boom.position = center
	Fx.play(get_parent(), center, FX_BURST, explode_radius * 1.6, 0.55, 0.5)
	_die()


## 附近最近的单位（用来攻击 / 自爆）。
func _find_unit(radius: float):
	var best = null
	var best_distance := radius
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.being_dragged or unit.is_ghost:
			continue
		var distance: float = position.distance_to(unit.position)
		if distance <= best_distance:
			best = unit
			best_distance = distance
	return best


func _arrive() -> void:
	if _done:
		return
	_done = true
	remove_from_group("enemies")
	reached_base.emit(self)


func _die() -> void:
	if _dead:
		return
	_dead = true
	_done = true
	remove_from_group("enemies")
	set_process(false)
	Fx.play(get_parent(), position, FX_SMOKE, 1.3, 0.45, 0.6)
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.18)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func _draw() -> void:
	if _dead or hp >= max_hp:
		return
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var color := Color(0.35, 0.82, 0.38)
	if ratio <= 0.25:
		color = Color(0.90, 0.25, 0.20)
	elif ratio <= 0.5:
		color = Color(0.95, 0.70, 0.25)
	draw_rect(Rect2(-BAR_WIDTH * 0.5, BAR_TOP, BAR_WIDTH, BAR_HEIGHT), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(-BAR_WIDTH * 0.5, BAR_TOP, BAR_WIDTH * ratio, BAR_HEIGHT), color)
