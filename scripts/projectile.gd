extends Node2D

## 炮弹：
##   火箭 —— 单体伤害，命中后让敌人持续燃烧。
##   炮船炮弹 —— 落地范围伤害，有概率对主目标一击必杀。

const BOOM_SCENE := preload("res://scenes/entities/boom.tscn")
const FX_BURST := preload("res://assets/fx/burst.png")
const FX_DROPS := preload("res://assets/fx/drops.png")

enum Kind { ROCKET, SHELL }

var _kind := Kind.ROCKET
var _target: Node2D
var _damage := 10.0
var _speed := 16.0
var _burn_dps := 0.0
var _burn_time := 0.0
var _aoe_radius := 0.0
var _instakill := 0.0


func setup_rocket(target: Node2D, damage: float, burn_dps: float, burn_time: float) -> void:
	_kind = Kind.ROCKET
	_target = target
	_damage = damage
	_burn_dps = burn_dps
	_burn_time = burn_time
	_speed = 16.0
	queue_redraw()


func setup_shell(target: Node2D, damage: float, aoe_radius: float, instakill: float) -> void:
	_kind = Kind.SHELL
	_target = target
	_damage = damage
	_aoe_radius = aoe_radius
	_instakill = instakill
	_speed = 9.0
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	var to_target: Vector2 = _target.position - position
	var step := _speed * delta
	if to_target.length() <= step:
		_hit()
		return

	position += to_target.normalized() * step
	rotation = to_target.angle()


func _hit() -> void:
	if _kind == Kind.ROCKET:
		if is_instance_valid(_target):
			_target.take_damage(_damage)
			_target.apply_burn(_burn_dps, _burn_time)
			Fx.play(get_parent(), _target.position, FX_DROPS, 0.95, 0.7, 0.35)
	else:
		var impact: Vector2 = _target.position
		if is_instance_valid(_target) and randf() < _instakill:
			_target.take_damage(_target.hp + _damage)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.position.distance_to(impact) <= _aoe_radius:
				enemy.take_damage(_damage)

		var boom = BOOM_SCENE.instantiate()
		boom.radius = _aoe_radius
		get_parent().add_child(boom)
		boom.position = impact
		Fx.play(get_parent(), impact, FX_BURST, _aoe_radius * 1.5, 0.5, 0.45)
	queue_free()


func _draw() -> void:
	if _kind == Kind.ROCKET:
		draw_line(Vector2(-0.65, 0.0), Vector2.ZERO, Color(1.0, 0.60, 0.20, 0.40), 0.08, true)
		draw_circle(Vector2.ZERO, 0.20, Color(1.0, 0.55, 0.20, 0.30))
		draw_circle(Vector2.ZERO, 0.09, Color(1.0, 0.86, 0.55))
	else:
		draw_line(Vector2(-0.75, 0.0), Vector2.ZERO, Color(0.45, 0.38, 0.55, 0.35), 0.12, true)
		draw_circle(Vector2.ZERO, 0.24, Color(0.40, 0.33, 0.50, 0.35))
		draw_circle(Vector2.ZERO, 0.13, Color(0.80, 0.75, 0.92))
