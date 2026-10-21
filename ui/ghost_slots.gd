class_name GhostSlots
extends Control
## 좌상단 고스트 슬롯(기획서 HUD: ●●○ = 3명 중 2명 사용). 덮어쓰기로 고른 슬롯은 흰 테두리로 깜빡인다.
## 상태를 읽어 그리기만 하므로 _process(연출)에서 갱신한다.

const RADIUS: float = 12.0
const GAP: float = 34.0

var loop_manager: LoopManager


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if loop_manager == null:
		return
	var ghosts: Array[Ghost] = loop_manager.ghosts()
	var slots: int = maxi(loop_manager.max_ghosts, ghosts.size())
	for i in slots:
		var center: Vector2 = Vector2(RADIUS + i * GAP, RADIUS)
		var color: Color = Palette.ghost(i + 1)
		if i < ghosts.size():
			draw_circle(center, RADIUS, color)
		else:
			draw_arc(center, RADIUS - 1.5, 0.0, TAU, 32, Color(color, 0.45), 3.0)
		if loop_manager.overwrite_target == i + 1 and int(Time.get_ticks_msec() / 300) % 2 == 0:
			draw_arc(center, RADIUS + 4.0, 0.0, TAU, 32, Palette.ME, 3.0)
