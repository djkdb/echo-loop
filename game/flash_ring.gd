class_name FlashRing
extends Node2D
## CLEAR 순간 출구에서 퍼지는 빛 고리(연출 전용).

const SECONDS: float = 0.5
var _age: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 25


func _process(delta: float) -> void:
	_age += delta
	if _age >= SECONDS:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(_age / SECONDS, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 30.0 + 40.0 * k, Color(Palette.EXIT, 0.5 * (1.0 - k)))
	draw_arc(Vector2.ZERO, 30.0 + 160.0 * k, 0.0, TAU, 48, Color(Palette.EXIT, 1.0 - k), 4.0 * (1.0 - k) + 1.0)
