class_name FullscreenButton
extends Control
## 웹(터치 기기)에서 전체 화면을 제안하는 알약 버튼. 브라우저는 사용자 입력 안에서만 전체 화면을 허락하므로
## 버튼을 눌렀을 때 요청한다. 웹·터치가 아니거나 이미 전체 화면이면 숨는다.
## show_after_touch = true면 첫 터치 뒤에 나타나 SHOW_SECONDS 동안만 보인다(게임 화면용).

const SHOW_SECONDS: float = 6.0

## 테스트가 웹이 아닌 곳에서도 켜 보려고 쓴다.
static var force_web: bool = false

@export var show_after_touch: bool = false

var _touched: bool = false
var _left: float = 0.0
var _font: Font = preload("res://assets/fonts/hud_font.tres")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if size == Vector2.ZERO:
		size = Vector2(200, 56)


static func applicable() -> bool:
	var web: bool = force_web or OS.has_feature("web")
	return web and TouchControls.enabled() and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and not _touched:
		_touched = true
		_left = SHOW_SECONDS


func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	visible = applicable() and (not show_after_touch or _left > 0.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap:
		accept_event()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_left = 0.0


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(Palette.ROOM, 0.9))
	draw_rect(r.grow(-1.5), Palette.EXIT, false, 3.0)
	# 네 귀퉁이 꺾쇠(전체 화면 아이콘, 글꼴에 없는 기호라 직접 그림) + 글자
	var c := Vector2(30, size.y * 0.5)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner: Vector2 = c + Vector2(sx, sy) * 11.0
			draw_line(corner, corner - Vector2(sx * 7.0, 0), Palette.EXIT, 3.0)
			draw_line(corner, corner - Vector2(0, sy * 7.0), Palette.EXIT, 3.0)
	draw_string(_font, Vector2(48, size.y * 0.5 + 10), "전체 화면", HORIZONTAL_ALIGNMENT_CENTER, size.x - 56, 28, Palette.EXIT)
