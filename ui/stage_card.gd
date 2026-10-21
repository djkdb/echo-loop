class_name StageCard
extends Control
## 스테이지 선택 화면의 카드 하나: 스테이지 번호, 별점, 잠김 표시. 키보드 포커스·클릭·터치로 고른다.

signal chosen(stage_id: String)
signal focused(stage_id: String)

var stage_id: String = ""
var code: String = ""
var unlocked: bool = false
var cleared: bool = false
var stars: int = 0

var _font: Font = preload("res://assets/fonts/hud_font.tres")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(func() -> void:
		queue_redraw()
		focused.emit(stage_id))
	focus_exited.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	var press: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		press = true
	if press:
		accept_event()
		if unlocked:
			chosen.emit(stage_id)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var line: Color = Palette.EXIT if cleared else Palette.WALL_LINE
	if not unlocked:
		line = Color(Palette.WALL_LINE, 0.5)
	draw_rect(r, Palette.ROOM)
	if has_focus():
		draw_rect(r.grow(4.0), Color(Palette.ME, 0.9), false, 3.0)
	draw_rect(r.grow(-1.5), line, false, 3.0)
	var text_color: Color = Palette.ME if unlocked else Color(Palette.SUB_TEXT, 0.5)
	draw_string(_font, Vector2(0, size.y * 0.48), code, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, text_color)
	if unlocked:
		var sr: float = 10.0
		for i in 3:
			var c := Vector2(size.x * 0.5 + (i - 1) * (sr * 2.0 + 6.0), size.y * 0.75)
			var pts: PackedVector2Array = StarIcons.star_points(c, sr)
			if i < stars:
				draw_colored_polygon(pts, Palette.SIGNAL)
			else:
				pts.append(pts[0])
				draw_polyline(pts, Color(Palette.SUB_TEXT, 0.5), 1.5, true)
	else:
		# 자물쇠: 몸통 + 고리
		var c := Vector2(size.x * 0.5, size.y * 0.76)
		draw_rect(Rect2(c + Vector2(-11, -4), Vector2(22, 16)), Color(Palette.SUB_TEXT, 0.6))
		draw_arc(c + Vector2(0, -4), 7.0, PI, TAU, 12, Color(Palette.SUB_TEXT, 0.6), 2.5)
