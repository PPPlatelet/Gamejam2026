class_name Fx
extends RefCounted

## 一次性水墨特效：在指定位置放一张墨迹图，放大 + 淡出后自删。
## size 是特效的初始宽度（格），grow 是放大比例，duration 是秒数。

static func play(parent: Node, at: Vector2, texture: Texture2D, size: float,
		grow := 0.6, duration := 0.45) -> void:
	if texture == null or parent == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.z_index = 8
	var factor := size / maxf(1.0, float(texture.get_width()))
	sprite.scale = Vector2(factor, factor)
	parent.add_child(sprite)
	sprite.position = at

	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE * factor * (1.0 + grow), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, duration)
	tween.tween_callback(sprite.queue_free)
