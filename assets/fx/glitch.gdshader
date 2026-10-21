shader_type canvas_item;
// 패러독스 붕괴: 가로 조각이 어긋나고 RGB가 갈라지며 깜빡인다. intensity로 세기, fade로 투명도.
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	float t = floor(TIME * 30.0) + seed;
	float slice = floor(UV.y * 14.0);
	float off = (hash(slice + t) - 0.5) * 0.4 * intensity;
	if (hash(slice * 3.1 + t) < 0.4 * intensity) { off *= 2.0; }
	vec2 uv = UV + vec2(off, 0.0);
	float split = 0.05 * intensity;
	vec4 m = texture(TEXTURE, uv);
	vec4 r = texture(TEXTURE, uv + vec2(split, 0.0));
	vec4 b = texture(TEXTURE, uv - vec2(split, 0.0));
	float a = max(m.a, max(r.a, b.a));
	if (uv.x < 0.0 || uv.x > 1.0) { a = 0.0; }
	float flicker = 1.0 - 0.5 * step(0.7, hash(slice + t + 7.0)) * intensity;
	COLOR = vec4(r.r, m.g, b.b, a * flicker * fade);
}
