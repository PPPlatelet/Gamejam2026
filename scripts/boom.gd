extends Node2D

## 炮弹落地的范围特效：一圈快速扩散并淡出的光晕。

var radius := 1.0
var _time := 0.0
const DURATION := 0.35


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_time / DURATION, 0.0, 1.0)
	var current := radius * (0.25 + 0.75 * k)
	draw_circle(Vector2.ZERO, current, Color(1.0, 0.70, 0.25, 0.18 * (1.0 - k)))
	draw_arc(Vector2.ZERO, current, 0.0, TAU, 40, Color(1.0, 0.80, 0.40, 0.85 * (1.0 - k)), 0.08, true)
