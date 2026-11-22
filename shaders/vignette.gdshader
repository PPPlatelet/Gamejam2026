shader_type canvas_item;

// 电影感暗角 + 很轻的胶片颗粒。用在开屏和开始菜单的最上层。
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.62;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.028;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.36;
uniform float outer_radius : hint_range(0.0, 1.5) = 0.82;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered * vec2(1.15, 1.0));
	float vignette = smoothstep(inner_radius, outer_radius, dist);
	float grain = (hash(UV * vec2(1920.0, 1080.0) + vec2(TIME * 37.0, TIME * 17.0)) - 0.5) * grain_strength;
	float alpha = clamp(vignette * vignette_strength + grain, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
