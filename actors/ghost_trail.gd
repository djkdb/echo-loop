extends Node2D
## 고스트 잔상: 녹화에서 6틱 간격 앞선 위치 3장을 외곽선만, 투명도 28 → 18 → 10%로 그린다(연출 전용).

const STEP: int = 6
const ALPHAS: Array[float] = [0.28, 0.18, 0.10]

var ghost: Ghost


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ghost == null or not ghost.alive:
		return
	var frames: Array[Dictionary] = ghost.frames()
	var now: int = mini(ghost.current_tick(), frames.size()) - 1
	if now < 0:
		return
	var here: Vector2 = frames[now]["pos"]
	var color: Color = Palette.ghost(ghost.number)
	for k in ALPHAS.size():
		var i: int = now - STEP * (k + 1)
		if i < 0:
			break
		var off: Vector2 = (frames[i]["pos"] as Vector2) - here
		if off.length() < 2.0:
			continue
		var pts: PackedVector2Array = CharacterVisual.round_rect_points(Rect2(off - Vector2(20, 32), Vector2(40, 64)).grow(-1.0), 10.0)
		pts.append(pts[0])
		draw_polyline(pts, Color(color, ALPHAS[k]), 2.0, true)
