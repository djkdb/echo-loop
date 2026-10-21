class_name TouchControls
extends Node2D
## 모바일 터치 조작(HUD 안, 화면 좌표). 하단 왼쪽 ← →, 오른쪽 E·점프, 상단 고스트 아이콘 탭 = 그 번호 다시 찍기,
## 시간 바 길게 누르기 = 루프 종료, 오른쪽 위 ≡ = 스테이지 선택(Esc).
## TouchScreenButton이 입력 액션을 그대로 눌러 주므로 게임 로직은 키보드와 같은 길로 받는다.
## 터치 화면이 없으면(데스크톱) 숨긴다. 데스크톱에서 확인하려면 실행 인자에 --touch.

const HOLD_SECONDS: float = 0.5
const TIMER_BAR: Rect2 = Rect2(40, 12, 640, 64)
const SLOT_ORIGIN: Vector2 = Vector2(52, 88)
const SLOT_GAP: float = 34.0

## 테스트가 터치 화면 없이도 켜 보려고 쓴다.
static var force_enabled: bool = false

var buttons: Dictionary = {}
var _hold: TouchScreenButton
var _hold_time: float = 0.0
var _hold_fired: bool = false
var _release_end_loop: bool = false
var _font: Font = preload("res://assets/fonts/hud_font.tres")


func _ready() -> void:
	visible = enabled()
	_add_round("left", Vector2(84, 1132), 56.0, "move_left", "◀")
	_add_round("right", Vector2(220, 1132), 56.0, "move_right", "▶")
	_add_round("interact", Vector2(500, 1136), 48.0, "interact", "E")
	_add_round("jump", Vector2(636, 1124), 62.0, "jump", "▲")
	_add_round("menu", Vector2(672, 122), 28.0, "ui_cancel", "≡")
	for n in range(1, 5):
		var b: TouchScreenButton = _add_button("ghost_%d" % n, SLOT_ORIGIN + Vector2((n - 1) * SLOT_GAP, 0), _rect_shape(Vector2(SLOT_GAP, 56)), "select_ghost_%d" % n)
		b.passby_press = false
	_hold = _add_button("timer", TIMER_BAR.get_center(), _rect_shape(TIMER_BAR.size), "")


static func enabled() -> bool:
	return force_enabled or DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")


func _process(delta: float) -> void:
	visible = enabled()
	# 루프 종료는 한 번 눌렀다 떼는 입력이면 충분하다. 다음 프레임에 뗀다.
	if _release_end_loop:
		_release_end_loop = false
		Input.action_release("end_loop")
	if _hold.is_pressed():
		_hold_time += delta
		if _hold_time >= HOLD_SECONDS and not _hold_fired:
			_hold_fired = true
			Input.action_press("end_loop")
			_release_end_loop = true
	else:
		_hold_time = 0.0
		_hold_fired = false
	queue_redraw()


func _draw() -> void:
	# 시간 바를 누르고 있는 동안 위에 채워지는 막대(놓으면 사라짐)
	if _hold.is_pressed() and not _hold_fired:
		var k: float = clampf(_hold_time / HOLD_SECONDS, 0.0, 1.0)
		draw_rect(Rect2(TIMER_BAR.position + Vector2(0, 20), Vector2(TIMER_BAR.size.x * k, 24)), Color(Palette.DOOR, 0.6))
	for key: String in ["left", "right", "interact", "jump", "menu"]:
		var b: TouchScreenButton = buttons[key]
		var r: float = (b.shape as CircleShape2D).radius
		var on: bool = b.is_pressed()
		draw_circle(b.position, r, Color(Palette.ME, 0.22 if on else 0.08))
		draw_arc(b.position, r - 1.5, 0.0, TAU, 48, Color(Palette.ME, 0.8 if on else 0.4), 3.0)
		var label: String = b.get_meta("label")
		var fs: int = 44 if key != "menu" else 34
		draw_string(_font, b.position + Vector2(-r, fs * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(Palette.ME, 0.9 if on else 0.6))


func _add_round(key: String, pos: Vector2, radius: float, action: String, label: String) -> TouchScreenButton:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var b: TouchScreenButton = _add_button(key, pos, shape, action)
	b.set_meta("label", label)
	return b


func _add_button(key: String, pos: Vector2, shape: Shape2D, action: String) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.name = key
	b.shape = shape
	b.position = pos
	b.action = action
	# 손가락을 떼지 않고 ← →를 오가도 눌림이 따라오게
	b.passby_press = true
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	add_child(b)
	buttons[key] = b
	return b


func _rect_shape(s: Vector2) -> RectangleShape2D:
	var r := RectangleShape2D.new()
	r.size = s
	return r
