class_name Timeline
extends Control
## 화면 하단 루프 타임라인: 고스트별 가로줄(+ 맨 아래 지금의 나)에 점프(작은 점)·interact(마름모) 시점과
## 현재 틱 커서를 그린다. "1번이 4초에 버튼을 누른다"를 눈으로 계획하게 하는 장치.

var loop_manager: LoopManager
var player: Player


func _process(_delta: float) -> void:
	queue_redraw()


## 줄마다 {color, jumps, interacts, collapsed_at, benched}. tick은 1부터(녹화 i번째 = i+1틱).
func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if loop_manager == null:
		return out
	for ghost: Ghost in loop_manager.ghosts():
		var row: Dictionary = _events(ghost.frames())
		row["color"] = Ghost.COLORS[(ghost.number - 1) % Ghost.COLORS.size()]
		row["collapsed_at"] = ghost.collapsed_at_tick
		row["benched"] = ghost.benched
		out.append(row)
	if player != null:
		var me: Dictionary = _events(player.recording)
		me["color"] = Color(0.95, 0.95, 0.95, 1)
		me["collapsed_at"] = -1
		me["benched"] = false
		out.append(me)
	return out


func _events(frames: Array[Dictionary]) -> Dictionary:
	var jumps: PackedInt32Array = []
	var interacts: PackedInt32Array = []
	for i in frames.size():
		if frames[i].get("jump", false):
			jumps.append(i + 1)
		if frames[i]["interact"]:
			interacts.append(i + 1)
	return {"jumps": jumps, "interacts": interacts}


func _draw() -> void:
	if loop_manager == null or loop_manager.loop_ticks <= 0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var data: Array[Dictionary] = rows()
	var row_h: float = size.y / maxf(float(data.size()), 1.0)
	for r in data.size():
		var row: Dictionary = data[r]
		var y: float = row_h * (r + 0.5)
		var color: Color = row["color"]
		if row["benched"]:
			color.a = 0.25
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(color, color.a * 0.5), 2.0)
		for t: int in row["jumps"]:
			draw_circle(Vector2(_x(t), y), 3.0, color)
		for t: int in row["interacts"]:
			var p: Vector2 = Vector2(_x(t), y)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), color)
		if row["collapsed_at"] >= 0:
			var c: Vector2 = Vector2(_x(row["collapsed_at"]), y)
			draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), Color.RED, 3.0)
			draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), Color.RED, 3.0)
	var cx: float = _x(loop_manager.tick)
	draw_line(Vector2(cx, 0), Vector2(cx, size.y), Color(1, 1, 1, 0.8), 2.0)


func _x(t: int) -> float:
	return size.x * clampf(float(t) / float(loop_manager.loop_ticks), 0.0, 1.0)
