class_name Level
extends Node2D
## 레벨 씬 루트. Main이 여기서 스폰 위치와 출구를 받아 Player·LoopManager에 연결한다.
## 루프 길이·고스트 상한은 스테이지마다 다르므로(기획서: 6~15초, 1~4명) 레벨이 갖고, LoopManager가 읽는다.

@export var spawn_point: Marker2D
@export var exit: Exit
@export var loop_seconds: float = 10.0
@export var max_ghosts: int = 2
## 보통 화면 줌. 몸·점프 수치는 그대로 두고 방을 작게 짜서 줌으로 키운다(RoomCamera).
## 챕터 1은 2.0(방 내부 약 320x360 = 폭 8명), 이후는 1.5 중심(약 480x486까지). 방이 화면 y 300~1030에
## 다 안 들어가면 카메라가 들어갈 만큼 줄인다.
@export_range(1.5, 2.0, 0.05) var camera_zoom: float = 1.5


func _ready() -> void:
	_apply_room_style()
	# 자식(오브젝트)의 _ready가 먼저 끝나 sources가 풀린 뒤라 신호선을 만들 수 있다.
	var wires := SignalWires.new()
	wires.name = "SignalWires"
	add_child(wires)
	move_child(wires, 1)
	wires.build(self)


## 방 내부(벽 안쪽) 사각형. 바닥·천장·양쪽 벽 이름(Floor, Ceiling, LeftWall, RightWall)으로 찾고,
## 없으면 화면 전체. 방 스타일과 카메라(RoomCamera)가 쓴다.
func room_rect() -> Rect2:
	var left: float = 0.0
	var right: float = 720.0
	var top: float = 0.0
	var bottom: float = 1280.0
	var room: Node = get_node_or_null("Room")
	if room == null:
		return Rect2(left, top, right - left, bottom - top)
	for name_: String in ["LeftWall", "RightWall", "Ceiling", "Floor"]:
		var body: Node = room.get_node_or_null(name_)
		if body == null:
			continue
		var r: Rect2 = _body_rect(body as StaticBody2D)
		match name_:
			"LeftWall": left = r.end.x
			"RightWall": right = r.position.x
			"Ceiling": top = r.end.y
			"Floor": bottom = r.position.y
	return Rect2(left, top, right - left, bottom - top)


func _apply_room_style() -> void:
	var room: Node = get_node_or_null("Room")
	if room == null:
		return
	var style := RoomStyle.new()
	style.name = "RoomStyle"
	style.room_rect = room_rect()
	for body: Node in room.get_children():
		if body is StaticBody2D:
			style.walls.append(_body_rect(body))
			for child: Node in body.get_children():
				if child is Polygon2D:
					(child as Polygon2D).visible = false
	var bg: Node = get_node_or_null("Background")
	if bg is CanvasItem:
		(bg as CanvasItem).visible = false
	add_child(style)
	move_child(style, 0)


func _body_rect(body: StaticBody2D) -> Rect2:
	for child: Node in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			var cs: CollisionShape2D = child
			var size: Vector2 = (cs.shape as RectangleShape2D).size
			return Rect2(body.global_position + cs.position - size * 0.5, size)
	return Rect2(body.global_position, Vector2.ZERO)
