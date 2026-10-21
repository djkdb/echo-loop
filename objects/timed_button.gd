class_name TimedButton
extends Area2D
## interact로 누르면 on_seconds 동안 on. 켜져 있는 동안 다시 누르면 시간이 처음부터 다시 흐른다.
##
## 실행 순서: process_physics_priority = 10. 누르는 건 Ghost/Player 차례에 일어나고,
## 같은 틱의 내 차례에서 그 틱부터 남은 시간을 센다.

signal toggled(on: bool)

@export var on_seconds: float = 3.0

var is_on: bool = false
## 이번 틱을 포함해 남은 on 틱 수. 0이 된 다음 틱에 꺼져서 정확히 on_seconds만큼 켜져 있다.
var ticks_left: int = 0

var _on_ticks: int = 0

@onready var _visual: Polygon2D = $Visual
@onready var _timer_bar: Node2D = $TimerBar


func _ready() -> void:
	add_to_group("resettable")
	add_to_group("interactables")
	_on_ticks = int(on_seconds * Engine.physics_ticks_per_second)


func _physics_process(_delta: float) -> void:
	if not is_on:
		return
	if ticks_left == 0:
		_set_on(false)
		return
	ticks_left -= 1
	_timer_bar.scale.x = float(ticks_left) / float(_on_ticks)


func interact() -> void:
	ticks_left = _on_ticks
	_set_on(true)


func reset() -> void:
	ticks_left = 0
	_timer_bar.scale.x = 0.0
	_set_on(false)


func _set_on(on: bool) -> void:
	if is_on == on:
		return
	is_on = on
	_visual.color = Color(0.4, 0.95, 1.0, 1) if on else Color(0.2, 0.45, 0.55, 1)
	toggled.emit(on)
