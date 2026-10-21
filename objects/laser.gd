class_name Laser
extends Node2D
## 레이저: 빔에 닿은 고스트는 붕괴, 지금의 나(Player)는 루프 즉시 실패(이번 녹화는 저장하지 않음).
## 빔은 direction으로 뻗다가 world(벽·문·발판·상자)에 막힌다. sources가 있으면 "하나라도 on"일 때만 켜진다
## (inverted면 반대). sources가 비어 있으면 항상 켜져 있다.
##
## 실행 순서: process_physics_priority = 25. 바디·소스·문이 이번 틱 처리를 끝낸 뒤 판정한다.
## 닿음은 Area2D 겹침 목록으로 본다. Player와 고스트의 감지 지연이 같아야 녹화와 재생이 같은 틱에 맞는다.

@export var sources: Array[NodePath] = []
@export var inverted: bool = false
@export var direction: Vector2 = Vector2.RIGHT
@export var max_length: float = 720.0
@export var beam_width: float = 8.0

var is_on: bool = false
var beam_length: float = 0.0

var _sources: Array[Node] = []
## Area2D 겹침 목록은 리셋 직후 첫 틱에 리셋 전 위치 기준이라(측정) 그 틱은 판정하지 않는다.
var _ignore_stale_overlaps: bool = false

@onready var _beam: Area2D = $Beam
@onready var _beam_shape: CollisionShape2D = $Beam/CollisionShape2D
@onready var _beam_line: Line2D = $BeamLine


func _ready() -> void:
	add_to_group("resettable")
	_sources = SignalSources.resolve(self, sources)
	_beam_shape.shape = _beam_shape.shape.duplicate()
	_update_beam()


func _physics_process(_delta: float) -> void:
	_update_beam()
	if _ignore_stale_overlaps:
		_ignore_stale_overlaps = false
		return
	if not is_on:
		return
	for body: Node2D in _beam.get_overlapping_bodies():
		if body is Player:
			get_tree().call_group("loop_manager", "fail_loop")
		elif body is Ghost:
			(body as Ghost).collapse()


func reset() -> void:
	_ignore_stale_overlaps = true
	_update_beam()


func _update_beam() -> void:
	is_on = _sources.is_empty() or (SignalSources.any_on(_sources) != inverted)
	var dir: Vector2 = direction.normalized()
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * max_length, 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	beam_length = global_position.distance_to(hit["position"]) if not hit.is_empty() else max_length
	var rect := _beam_shape.shape as RectangleShape2D
	rect.size = Vector2(beam_length, beam_width)
	_beam_shape.position = dir * beam_length * 0.5
	_beam_shape.rotation = dir.angle()
	_beam_shape.disabled = not is_on
	_beam_line.visible = is_on
	_beam_line.points = PackedVector2Array([Vector2.ZERO, dir * beam_length])
