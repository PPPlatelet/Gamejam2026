shader_type canvas_item;

// 船坞下方水影的轻微波动：只扰动图片下部（水面）的采样坐标，
// 船体和码头保持不动。
uniform float water_start : hint_range(0.0, 1.0) = 0.72;
uniform float strength = 0.006;

void fragment() {
	vec2 uv = UV;
	if (uv.y > water_start) {
		float k = (uv.y - water_start) / max(0.001, 1.0 - water_start);
		uv.x += sin(TIME * 1.6 + uv.y * 24.0) * strength * k;
		uv.y += cos(TIME * 1.2 + uv.x * 18.0) * strength * 0.6 * k;
	}
	COLOR = texture(TEXTURE, uv) * COLOR;
}
