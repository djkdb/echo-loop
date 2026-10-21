class_name Box
extends AnimatableBody2D
## 밀 수 있는 상자. 압력판을 누르고, 위에 올라설 수 있고, 루프마다 원위치로 돌아간다.
##
## 밀기는 물리 엔진에 맡기지 않고 위치 규칙으로 한다: 몸(Player·살아 있는 고스트)이 상자 옆면을 파고든 만큼
## 상자를 밀어낸다. Player는 이번 틱 위치, 고스트는 replay_position을 써서 녹화 루프(Player가 밂)와
## 재생 루프(같은 경로의 고스트가 밂)에서 상자가 똑같이 움직인다(결정론). 그래서 충돌은 윗면만(one-way)이다.
##
## 실행 순서: process_physics_priority = 0. Ghost(-20)·Player(-10)가 이번 틱 위치를 정한 뒤 밀리고,
## 압력판(10)보다 먼저 움직인다.

@export var gravity: float = 2400.0
@export var max_fall_speed: float = 1400.0

## 이번 틱에 가기로 한 위치(sync_to_physics라 global_position은 물리 스텝 뒤에 따라온다).
var box_position: Vector2 = Vector2.ZERO

var _start: Vector2 = Vector2.ZERO
var _fall_speed: float = 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	sync_to_physics = true
	add_to_group("resettable")
	_start = global_position
	box_position = _start
	$Visual.visible = false
	$Cross.visible = false


## 연출: 어두운 채움 + 보조색 외곽선 + X 무늬.
func _draw() -> void:
	var size: Vector2 = (_shape.shape as RectangleShape2D).size
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color("#161B2E"))
	draw_rect(r.grow(-1.5), Palette.SUB_TEXT, false, 3.0)
	var k: Rect2 = r.grow(-8.0)
	draw_line(k.position, k.end, Color(Palette.SUB_TEXT, 0.6), 2.0)
	draw_line(Vector2(k.end.x, k.position.y), Vector2(k.position.x, k.end.y), Color(Palette.SUB_TEXT, 0.6), 2.0)


func _physics_process(delta: float) -> void:
	var push: float = _push_from_actors()
	if push != 0.0:
		box_position.x += _free_travel(Vector2(push, 0.0)).x
	_fall_speed = minf(_fall_speed + gravity * delta, max_fall_speed)
	var fall: Vector2 = _free_travel(Vector2(0.0, _fall_speed * delta))
	if fall.y < _fall_speed * delta:
		_fall_speed = 0.0
	box_position.y += fall.y
	global_position = box_position


func reset() -> void:
	box_position = _start
	_fall_speed = 0.0
	global_position = _start


## 옆면을 파고든 몸들 때문에 밀려야 하는 x 거리. Player 먼저, 고스트는 번호 순(고정 순서 = 결정론).
func _push_from_actors() -> float:
	var push: float = 0.0
	var mine: Rect2 = _rect_at(box_position)
	for actor: Dictionary in _actors():
		var rect: Rect2 = actor["rect"]
		# 위에 올라서 있거나 아래에 있는 몸은 밀지 않는다(세로로 4px 넘게 겹칠 때만 옆면 접촉).
		var overlap_y: float = minf(rect.end.y, mine.end.y) - maxf(rect.position.y, mine.position.y)
		if overlap_y <= 4.0 or not rect.intersects(mine):
			continue
		if rect.get_center().x < mine.get_center().x:
			push = maxf(push, rect.end.x - mine.position.x)
		else:
			push = minf(push, rect.position.x - mine.end.x)
	return push


func _actors() -> Array[Dictionary]:
	var actors: Array[Dictionary] = []
	var ghosts: Array[Ghost] = []
	for node: Node in get_tree().get_nodes_in_group("resettable"):
		if node is Player:
			var player: Player = node
			actors.append({"rect": _body_rect(player.body_shape(), player.global_position)})
		elif node is Ghost and (node as Ghost).alive:
			ghosts.append(node)
	ghosts.sort_custom(func(a: Ghost, b: Ghost) -> bool: return a.number < b.number)
	for ghost: Ghost in ghosts:
		actors.append({"rect": _body_rect(ghost.body_shape(), ghost.replay_position)})
	return actors


## 지형(world)에 막히기 전까지 갈 수 있는 이동량.
func _free_travel(motion: Vector2) -> Vector2:
	var hit := KinematicCollision2D.new()
	if test_move(Transform2D(0.0, box_position), motion, hit):
		return hit.get_travel()
	return motion


func _rect_at(at: Vector2) -> Rect2:
	var r: Rect2 = _shape.shape.get_rect()
	r.position += at
	return r


func _body_rect(shape: Shape2D, at: Vector2) -> Rect2:
	var r: Rect2 = shape.get_rect()
	r.position += at
	return r
