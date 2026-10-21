class_name Door
extends StaticBody2D
## 연결된 소스 중 하나라도 on이면 열리는 문(규칙 7). world 레이어라 닫혀 있으면 고스트 경로를 막는다.
##
## 실행 순서: process_physics_priority = 20. 소스(압력판, 10)가 이번 틱 판정을 끝낸 뒤 열고 닫는다.

## is_on 프로퍼티를 가진 노드(압력판·레버·시한 버튼)들.
@export var sources: Array[NodePath] = []

var is_open: bool = false

var _sources: Array[Node] = []

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _sensor: Area2D = $Sensor
@onready var _visual: CanvasItem = $Visual


func _ready() -> void:
	add_to_group("resettable")
	for path: NodePath in sources:
		var source: Node = get_node_or_null(path)
		if source == null or not "is_on" in source:
			push_warning("Door %s: 소스 %s를 찾을 수 없거나 is_on이 없다." % [name, path])
			continue
		_sources.append(source)


func _physics_process(_delta: float) -> void:
	if _any_source_on():
		_set_open(true)
	elif is_open and not _is_occupied():
		# 끼임 방지: 문 영역에 누가 있으면 닫지 않고, 비는 틱에 닫는다.
		_set_open(false)


func reset() -> void:
	_set_open(false)


func _any_source_on() -> bool:
	for source: Node in _sources:
		if source.is_on:
			return true
	return false


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
