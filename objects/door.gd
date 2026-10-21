class_name Door
extends StaticBody2D
## 연결된 소스 중 하나라도 on이면 열리는 문(규칙 7). world 레이어라 닫혀 있으면 고스트 경로를 막는다.
## inverted면 반대로 평소에 열려 있다가 신호가 오면 닫힌다. 레버(지금의 내가 문을 닫음)와 함께
## 쓰면 "녹화 때 열려 있던 문이 재생 때 닫혀 있는" 패러독스가 생긴다.
##
## 실행 순서: process_physics_priority = 20. 소스(압력판·레버·시한 버튼, 10)가 이번 틱 판정을 끝낸 뒤 열고 닫는다.

## is_on 프로퍼티를 가진 노드(압력판·레버·시한 버튼)들.
@export var sources: Array[NodePath] = []
@export var inverted: bool = false

var is_open: bool = false

var _sources: Array[Node] = []

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _sensor: Area2D = $Sensor
@onready var _visual: CanvasItem = $Visual


func _ready() -> void:
	add_to_group("resettable")
	_sources = SignalSources.resolve(self, sources)
	_set_open(inverted)


func _physics_process(_delta: float) -> void:
	var want_open: bool = SignalSources.any_on(_sources) != inverted
	if want_open:
		_set_open(true)
	elif is_open and not _is_occupied():
		# 끼임 방지: 문 영역에 누가 있으면 닫지 않고, 비는 틱에 닫는다.
		_set_open(false)


func reset() -> void:
	# 리셋 직후엔 모든 소스가 off이므로 inverted 문은 열린 상태로 시작한다.
	_set_open(inverted)


func _is_occupied() -> bool:
	for body: Node2D in _sensor.get_overlapping_bodies():
		if body is Ghost and not (body as Ghost).alive:
			continue
		return true
	return false


func _set_open(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	# 충돌을 즉시 켜고 꺼야 같은 틱 기준으로 고스트의 test_move가 문 상태를 본다.
	_shape.disabled = open
	_visual.modulate.a = 0.15 if open else 1.0
