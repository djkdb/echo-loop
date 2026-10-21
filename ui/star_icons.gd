class_name StarIcons
extends Control
## 별 3개(얻은 별은 신호색, 못 얻은 별은 흐린 외곽선). 스테이지 카드·클리어 패널·선택 화면 합계가 쓴다.
## 글꼴에 ★ 글리프가 없어도 되게 다각형으로 그린다.

@export var count: int = 0:
	set(v):
		count = v
		queue_redraw()
@export var total: int = 3
@export var star_size: float = 20.0
@export var gap: float = 6.0


func _draw() -> void:
	var w: float = total * star_size * 2.0 + (total - 1) * gap
	var x0: float = (size.x - w) * 0.5 + star_size
	for i in total:
		var c := Vector2(x0 + i * (star_size * 2.0 + gap), size.y * 0.5)
		var pts: PackedVector2Array = StarIcons.star_points(c, star_size)
		if i < count:
			draw_colored_polygon(pts, Palette.SIGNAL)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(Palette.SUB_TEXT, 0.6), 2.0, true)


static func star_points(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a: float = -PI * 0.5 + PI * float(k) / 5.0
		var rr: float = r if k % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return pts
