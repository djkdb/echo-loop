shader_type canvas_item;
// 루프 리셋 되감기: 화면을 읽어 가로로 밀린 띠 + 스캔라인 + 색 번짐 + 차가운 색조. amount 1 → 0으로 사라진다.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 40.0);
	float t = floor(TIME * 24.0);
	uv.x += (hash(band + t) - 0.5) * 0.03 * amount + sin(uv.y * 30.0 + TIME * 40.0) * 0.004 * amount;
	float split = 0.006 * amount;
	vec3 c;
	c.r = texture(screen_texture, uv + vec2(split, 0.0)).r;
	c.g = texture(screen_texture, uv).g;
	c.b = texture(screen_texture, uv - vec2(split, 0.0)).b;
	float scan = 0.85 + 0.15 * sin(SCREEN_UV.y * 1280.0 * 1.5);
	vec3 tint = mix(c, vec3(dot(c, vec3(0.3, 0.5, 0.2))) * vec3(0.75, 0.9, 1.25), 0.55 * amount);
	COLOR = vec4(tint * mix(1.0, scan, amount), 1.0);
}
