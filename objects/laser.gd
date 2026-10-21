class_name Laser
extends Node2D
## 레이저: 지금의 나(Player)가 빔에 닿으면 루프 즉시 실패(이번 녹화는 저장하지 않음).
## 빔은 direction으로 뻗다가 world(벽·문·발판·상자)나 고스트에 막힌다. 고스트는 몸으로 빔을 막는 방패이고
## 붕괴하지 않는다(기획서 2-3 "방패"). 붕괴했거나 덮어쓰기로 빠진 고스트는 충돌이 꺼져 있어 막지 않는다. sources가 있으면 "하나라도 on"일 때만 켜진다
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
## Area2D 겹침 목록은 리셋 뒤 물리 스텝이 한 번 돌고 나서야 새 위치를 반영한다(측정: 틱 끝 리셋이면 다음 1틱이 낡음).
## 그 사이에 판정하면 리셋 전 위치의 바디 때문에 판이 눌리거나 출구에서 다시 CLEAR가 된다.
## 리셋이 틱 중간·시작에 일어나도 맞도록 리셋된 물리 프레임에서 2프레임이 지날 때까지 겹침을 쓰지 않는다.
var _reset_frame: int = -100

@onready var _beam: Area2D = $Beam
@onready var _beam_shape: CollisionShape2D = $Beam/CollisionShape2D
@onready var _beam_line: Line2D = $BeamLine
@onready var _beam_glow: Line2D = $BeamGlow


func _ready() -> void:
	add_to_group("resettable")
	_sources = SignalSources.resolve(self, sources)
	_beam_shape.shape = _beam_shape.shape.duplicate()
	_update_beam()


func _physics_process(_delta: float) -> void:
	_update_beam()
	if Engine.get_physics_frames() - _reset_frame < 2:
		return
	if not is_on:
		return
	for body: Node2D in _beam.get_overlapping_bodies():
		if body is Player:
			get_tree().call_group("loop_manager", "fail_loop")


func reset() -> void:
	_reset_frame = Engine.get_physics_frames()
	_update_beam()


func _update_beam() -> void:
	is_on = _sources.is_empty() or (SignalSources.any_on(_sources) != inverted)
	var dir: Vector2 = direction.normalized()
	# world(1) + ghost(3): 고스트가 빔을 막는다.
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * max_length, 1 | 4)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	beam_length = global_position.distance_to(hit["position"]) if not hit.is_empty() else max_length
	var rect := _beam_shape.shape as RectangleShape2D
	rect.size = Vector2(beam_length, beam_width)
	_beam_shape.position = dir * beam_length * 0.5
	_beam_shape.rotation = dir.angle()
	_beam_shape.disabled = not is_on
	_beam_line.visible = is_on
	_beam_line.points = PackedVector2Array([Vector2.ZERO, dir * beam_length])
	_beam_glow.visible = is_on
	_beam_glow.points = _beam_line.points


## 연출: 빔 글로우가 살짝 숨 쉰다.
func _process(_delta: float) -> void:
	_beam_glow.width = 18.0 + 4.0 * sin(Time.get_ticks_msec() * 0.012)


## 연결된 소스(신호선 연출이 읽는다).
func connected_sources() -> Array[Node]:
	return _sources
