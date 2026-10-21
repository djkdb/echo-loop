class_name CharacterVisual
extends Node2D
## Player·고스트 공용 몸 그림: 둥근 사각형 몸 + 진행 방향(+x)을 보는 눈 2개.
## 부모 Visual 노드가 scale.x = -1로 좌우를 뒤집으므로 여기서는 항상 오른쪽을 보는 모양을 그린다.
## 찌그러짐(squash)은 발밑을 기준으로 적용하고 _process에서 1로 되돌린다(연출 전용).

@export var size: Vector2 = Vector2(40, 64)
@export var body_color: Color = Palette.ME
@export var fill_alpha: float = 1.0
@export var outline_width: float = 0.0
@export var eye_color: Color = Palette.BG
@export var corner_radius: float = 10.0

var squash: Vector2 = Vector2.ONE
var _pulse_from: Vector2 = Vector2.ONE
var _pulse_time: float = 0.0
var _pulse_left: float = 0.0


## 잠깐 target 비율로 찌그러졌다가 duration 동안 원래대로.
func pulse(target: Vector2, duration: float) -> void:
	_pulse_from = target
	_pulse_time = duration
	_pulse_left = duration
	squash = target
	queue_redraw()


func _process(delta: float) -> void:
	if _pulse_left <= 0.0:
		return
	_pulse_left = maxf(_pulse_left - delta, 0.0)
	var t: float = 1.0 - _pulse_left / _pulse_time
	squash = _pulse_from.lerp(Vector2.ONE, t * t * (3.0 - 2.0 * t))
	queue_redraw()


func _draw() -> void:
	var feet: Vector2 = Vector2(0, size.y * 0.5)
	draw_set_transform(feet, 0.0, squash)
	var r := Rect2(-size * 0.5 - feet, size)
	var fill := Color(body_color, body_color.a * fill_alpha)
	_draw_round_rect(r, corner_radius, fill)
	if outline_width > 0.0:
		_draw_round_outline(r, corner_radius, body_color, outline_width)
	# 눈: 몸 위쪽 1/3, 진행 방향으로 치우친 두 개
	var eye_y: float = r.position.y + size.y * 0.3
	for ex: float in [size.x * 0.08, size.x * 0.32]:
		draw_rect(Rect2(Vector2(ex - 3.0, eye_y - 5.0), Vector2(6, 10)), eye_color)
	draw_set_transform(Vector2.ZERO)


static func round_rect_points(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad: float = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners: Array = [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5]]
	for c: Array in corners:
		for i in 5:
			var a: float = c[1] + PI * 0.5 * float(i) / 4.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


func _draw_round_rect(r: Rect2, radius: float, color: Color) -> void:
	draw_colored_polygon(round_rect_points(r, radius), color)


func _draw_round_outline(r: Rect2, radius: float, color: Color, width: float) -> void:
	var pts: PackedVector2Array = round_rect_points(r.grow(-width * 0.5), radius)
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)
