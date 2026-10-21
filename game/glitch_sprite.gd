class_name GlitchSprite
extends Sprite2D
## 붕괴한 고스트 자리에 잠깐 남는 글리치 잔상. 고스트 모양 텍스처를 코드로 그려 glitch 셰이더를 씌운다(연출 전용).

static var _textures: Dictionary = {}

var _left: float = 0.0
var _total: float = 0.45
var _mat: ShaderMaterial


func setup(color: Color, pos: Vector2, seconds: float) -> void:
	texture = _texture_for(color)
	position = pos
	top_level = true
	z_index = 15
	_total = seconds
	_left = seconds
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/fx/glitch.gdshader")
	_mat.set_shader_parameter("seed", float(randi() % 1000))
	material = _mat


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var k: float = _left / _total
	_mat.set_shader_parameter("intensity", 0.4 + 0.6 * k)
	_mat.set_shader_parameter("fade", k)
	scale = Vector2(1.0 + 0.25 * (1.0 - k), 1.0 - 0.15 * (1.0 - k))


## 둥근 사각형 고스트(채움 + 외곽선) 텍스처. 좌우 여백을 둬서 조각이 밀려도 잘리지 않게 한다.
static func _texture_for(color: Color) -> Texture2D:
	var key: String = color.to_html()
	if _textures.has(key):
		return _textures[key]
	var w: int = 96
	var h: int = 76
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Rect2(Vector2(28, 6), Vector2(40, 64))
	var rad: float = 10.0
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var d: float = _round_rect_sd(p, body, rad)
			if d <= 0.0:
				var edge: bool = d > -2.0
				img.set_pixel(x, y, color if edge else Color(color, 0.45))
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


static func _round_rect_sd(p: Vector2, r: Rect2, rad: float) -> float:
	var c: Vector2 = r.get_center()
	var q: Vector2 = (p - c).abs() - r.size * 0.5 + Vector2(rad, rad)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rad
