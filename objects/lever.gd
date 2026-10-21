class_name Lever
extends Area2D
## interact로 당기면 루프가 끝날 때까지 on을 유지한다(규칙 7의 보내는 쪽).
## 지금의 나와 고스트 모두 겹친 채 interact하면 당겨진다(고스트는 녹화된 interact 틱에).
##
## 실행 순서: process_physics_priority = 10. 당기는 건 Ghost(-20)/Player(-10)가 자기 차례에
## interact()를 불러서 일어나고, 받는 쪽(20)이 같은 틱에 반응한다.

signal toggled(on: bool)

var is_on: bool = false

@onready var _handle: Node2D = $Handle
@onready var _knob: Polygon2D = $Handle/Knob


func _ready() -> void:
	add_to_group("resettable")
	add_to_group("interactables")


func interact() -> void:
	# 한 번 당기면 끝: 다시 interact해도 꺼지지 않는다.
	_set_on(true)


func reset() -> void:
	_set_on(false)


func _set_on(on: bool) -> void:
	if is_on == on:
		return
	is_on = on
	toggled.emit(on)


## 연출: 손잡이가 0.1초에 걸쳐 넘어가고, 켜지면 손잡이 끝이 신호색으로.
func _process(delta: float) -> void:
	var target: float = deg_to_rad(35.0 if is_on else -35.0)
	_handle.rotation = move_toward(_handle.rotation, target, delta * deg_to_rad(700.0))
	_knob.color = Palette.SIGNAL if is_on else Palette.SUB_TEXT
