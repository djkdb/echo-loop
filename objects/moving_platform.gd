class_name MovingPlatform
extends AnimatableBody2D
## 신호가 있는 동안 시작 위치 ↔ 시작 위치 + travel 을 왕복하는 발판(규칙 7의 받는 쪽). sources가 비어 있으면 항상 움직인다.
## AnimatableBody2D(sync_to_physics)라 위에 선 Player가 같이 움직이고, world 레이어라 고스트 경로를 막을 수 있다.
##
## 실행 순서: process_physics_priority = 20. 소스(10)가 이번 틱 판정을 끝낸 뒤 움직인다.
## 위치는 "활성 상태로 지난 틱 수"만으로 계산해서, 같은 신호 타이밍이면 매 루프 같은 위치가 나온다(결정론).
##
## 끼임 방지: 다음 위치가 몸(Player·고스트)을 밀고, 민 자리가 지형에 막히면(짓누름) 그 틱은 멈춘다.
## 짓눌린 Player는 바닥을 뚫고 들어가 재생할 수 없는 녹화를 남기기 때문이다.
## 판정은 물리 쿼리 대신 사각형 계산으로, Player는 이번 틱 위치·고스트는 replay_position을 써서
## 녹화 루프(Player)와 재생 루프(고스트)에서 똑같이 나오게 한다.

@export var sources: Array[NodePath] = []
@export var inverted: bool = false
## 시작 위치에서 반대쪽 끝까지의 이동량.
@export var travel: Vector2 = Vector2(0, -200)
## 초당 이동 거리(px).
@export var speed: float = 120.0

var _sources: Array[Node] = []
var _start: Vector2 = Vector2.ZERO
var _active_ticks: int = 0
## 이번 틱에 가기로 한 위치(sync_to_physics라 global_position은 물리 스텝 뒤에 따라온다).
var _pos: Vector2 = Vector2.ZERO

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: CanvasItem = $Visual


func _ready() -> void:
	sync_to_physics = true
	add_to_group("resettable")
	_sources = SignalSources.resolve(self, sources)
	_start = global_position
	_pos = _start
	_visual.visible = false


## 연출: 어두운 채움 + 보조색 외곽선 + 신호색 점 3개.
func _draw() -> void:
	var size: Vector2 = (_shape.shape as RectangleShape2D).size
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color("#1A2036"))
	draw_rect(r.grow(-1.0), Palette.SUB_TEXT, false, 2.0)
	for i: int in [-1, 0, 1]:
		draw_circle(Vector2(i * 14.0, 0), 2.5, Color(Palette.SIGNAL, 0.6))


func _physics_process(_delta: float) -> void:
	var active: bool = _sources.is_empty() or (SignalSources.any_on(_sources) != inverted)
	if not active:
		return
	var next: Vector2 = _position_at(_active_ticks + 1)
	if _would_crush(next - _pos):
		return
	_active_ticks += 1
	_pos = next
	global_position = _pos


func reset() -> void:
	_active_ticks = 0
	_pos = _start
	global_position = _start


func _would_crush(motion: Vector2) -> bool:
	if motion == Vector2.ZERO:
		return false
	var mine: Rect2 = _shape.shape.get_rect()
	var next_rect: Rect2 = Rect2(mine.position + _pos + motion, mine.size)
	for actor: Dictionary in _actors():
		var body: PhysicsBody2D = actor["body"]
		var shape: Shape2D = actor["shape"]
		var rect: Rect2 = shape.get_rect()
		rect.position += actor["pos"]
		if not next_rect.intersects(rect):
			continue
		if _blocked_by_world(body, shape, actor["pos"] + motion):
			return true
	return false


## 밀릴 수 있는 몸과 "이번 틱 위치".
func _actors() -> Array[Dictionary]:
	var actors: Array[Dictionary] = []
	for node: Node in get_tree().get_nodes_in_group("resettable"):
		if node is Player:
			var player: Player = node
			actors.append({"body": player, "shape": player.body_shape(), "pos": player.global_position})
		elif node is Ghost and (node as Ghost).alive:
			var ghost: Ghost = node
			actors.append({"body": ghost, "shape": ghost.body_shape(), "pos": ghost.replay_position})
	return actors


func _blocked_by_world(body: PhysicsBody2D, shape: Shape2D, at: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at)
	# 닿아 있기만 한 바닥·벽은 막힘이 아니다(녹화 위치는 표면에서 0.08px 안팎).
	query.margin = -1.0
	# 그 몸을 막는 지형(world·색 문)만. 다른 몸(player·ghost 레이어)은 밀려날 수 있으니 제외.
	query.collision_mask = body.collision_mask & ~(2 | 4)
	query.exclude = [get_rid(), body.get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _position_at(ticks: int) -> Vector2:
	var length: float = travel.length()
	if length == 0.0:
		return _start
	var distance: float = speed * float(ticks) / float(Engine.physics_ticks_per_second)
	return _start + travel / length * pingpong(distance, length)


## 연결된 소스(신호선 연출이 읽는다).
func connected_sources() -> Array[Node]:
	return _sources
