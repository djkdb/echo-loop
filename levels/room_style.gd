class_name RoomStyle
extends Node2D
## 레벨 방을 NEON LOOP 스타일로 그린다: 바탕, 격자 있는 방 내부, 외곽선 있는 벽.
## 벽 모양은 Room 아래 StaticBody2D의 충돌 사각형에서 읽으므로 에디터에서 벽을 고치면 그대로 따라간다.
## 정적인 그림이라 처음 한 번만 그린다(게임 로직과 무관).

var room_rect: Rect2 = Rect2()
var walls: Array[Rect2] = []


func _draw() -> void:
	draw_rect(Rect2(-2000, -2000, 4720, 5280), Palette.BG)
	draw_rect(room_rect, Palette.ROOM)
	var x: float = room_rect.position.x
	while x <= room_rect.end.x:
		draw_line(Vector2(x, room_rect.position.y), Vector2(x, room_rect.end.y), Palette.GRID, 1.0)
		x += Palette.GRID_STEP
	var y: float = room_rect.end.y
	while y >= room_rect.position.y:
		draw_line(Vector2(room_rect.position.x, y), Vector2(room_rect.end.x, y), Palette.GRID, 1.0)
		y -= Palette.GRID_STEP
	for r: Rect2 in walls:
		draw_rect(r, Palette.BG)
	for r: Rect2 in walls:
		draw_rect(r.grow(-1.0), Palette.WALL_LINE, false, 2.0)
