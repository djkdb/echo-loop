class_name SoundToggle
extends Control
## 소리 켬/끔 버튼(타이틀·스테이지 선택 화면). 마우스·탭으로만 누른다(새 입력 액션 없음). 설정은 Progress 플래그로 저장된다.

var _font: Font = preload("res://assets/fonts/hud_font.tres")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if size == Vector2.ZERO:
		size = Vector2(150, 52)


func is_on() -> bool:
	return not Progress.has_flag(Progress.SOUND_OFF_FLAG)


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap:
		accept_event()
		Progress.set_sound_on(not is_on())
		queue_redraw()


func _draw() -> void:
	var on: bool = is_on()
	var ink: Color = Palette.ME if on else Palette.SUB_TEXT
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.ROOM, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size).grow(-1.5), Color(ink, 0.6), false, 2.0)
	# 스피커: 네모 + 나팔, 켜짐이면 소리 물결, 꺼짐이면 X
	var c := Vector2(30, size.y * 0.5)
	draw_rect(Rect2(c + Vector2(-12, -6), Vector2(8, 12)), ink)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -6), c + Vector2(6, -14), c + Vector2(6, 14), c + Vector2(-4, 6)]), ink)
	if on:
		draw_arc(c + Vector2(6, 0), 8.0, -PI * 0.3, PI * 0.3, 8, ink, 2.0)
		draw_arc(c + Vector2(6, 0), 14.0, -PI * 0.3, PI * 0.3, 10, ink, 2.0)
	else:
		draw_line(c + Vector2(12, -7), c + Vector2(24, 7), ink, 2.5)
		draw_line(c + Vector2(24, -7), c + Vector2(12, 7), ink, 2.5)
	draw_string(_font, Vector2(56, size.y * 0.5 + 9), "소리 켬" if on else "소리 끔", HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 24, ink)
