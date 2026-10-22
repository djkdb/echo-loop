class_name Title
extends Control
## 타이틀 화면: "ECHO LOOP" 로고(고스트 4색 잔상), 한 줄 설명, 과거의 나들이 같은 길을 따라 뛰는 짧은 연출, 조작 안내.
## Enter·Space·E 또는 화면 아무 곳 클릭·탭으로 스테이지 선택 화면.
## 연출만 있는 화면이라 전부 _process에서 그린다(게임 로직 없음).

const SELECT_SCENE: String = "res://ui/stage_select.tscn"
const LOGO_TEXT: String = "ECHO LOOP"
## 연출: 지금의 나가 왕복하는 길(화면 x)과 높이, 고스트가 따라오는 지연(초).
const RUN_LEFT: float = 150.0
const RUN_RIGHT: float = 570.0
const RUN_Y: float = 700.0
const ECHO_DELAY: float = 0.32
const CONTROLS: Array = [
	["← → / A D", "이동"],
	["Space", "점프"],
	["E", "레버 · 버튼"],
	["R", "루프 끝내기 (나를 고스트로)"],
	["Backspace", "마지막 고스트 지우기"],
	["1 ~ 4", "그 번호의 나 다시 찍기"],
	["Shift + R", "스테이지 처음부터"],
]

var _font: Font = preload("res://assets/fonts/hud_font.tres")
var _time: float = 0.0
var _runners: Array[CharacterVisual] = []
var _prompt: Label
var copy_button: Button
var _copied: Label
var _copied_left: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 뒤에서부터: 4번 고스트 … 1번 고스트, 맨 앞이 지금의 나
	for i in range(4, -1, -1):
		var v := CharacterVisual.new()
		if i == 0:
			v.body_color = Palette.ME
		else:
			v.body_color = Palette.ghost(i)
			v.eye_color = Palette.ghost(i)
			v.fill_alpha = Palette.GHOST_FILL_ALPHA
			v.outline_width = 2.0
		v.scale = Vector2(1.5, 1.5)
		add_child(v)
		_runners.push_front(v)
	_add_label("10초 전의 나와 손잡고 방을 탈출하는 퍼즐", Rect2(0, 470, 720, 50), 30, Palette.SUB_TEXT)
	var y: float = 840.0
	for row: Array in CONTROLS:
		var k: Label = _add_label(row[0], Rect2(60, y, 230, 40), 26, Palette.ME)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var a: Label = _add_label(row[1], Rect2(320, y, 380, 40), 26, Palette.SUB_TEXT)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		y += 40.0
	_add_label("모바일: 아래 버튼으로 이동·점프·E, 위 고스트 아이콘을 탭해 다시 찍기", Rect2(0, y + 10, 720, 36), 21, Color(Palette.SUB_TEXT, 0.7))
	_prompt = _add_label("ENTER / TAP", Rect2(0, 1170, 720, 60), 40, Palette.EXIT)
	# 플레이 테스트 결과 복사(친구가 카톡으로 붙여 보내는 용도). 누르면 시작하지 않고 클립보드에만 담는다.
	copy_button = Button.new()
	copy_button.name = "CopyResults"
	copy_button.text = "테스트 결과 복사"
	copy_button.flat = true
	copy_button.focus_mode = Control.FOCUS_NONE
	copy_button.position = Vector2(16, 1234)
	copy_button.size = Vector2(230, 40)
	copy_button.add_theme_font_override("font", _font)
	copy_button.add_theme_font_size_override("font_size", 22)
	copy_button.add_theme_color_override("font_color", Color(Palette.SUB_TEXT, 0.8))
	copy_button.add_theme_color_override("font_hover_color", Palette.ME)
	copy_button.pressed.connect(copy_results)
	add_child(copy_button)
	_copied = _add_label("", Rect2(250, 1234, 300, 40), 22, Palette.EXIT)
	_copied.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 웹·터치: 시작 전에 전체 화면을 고를 수 있게(누르면 시작하지 않고 전체 화면만)
	var fs := FullscreenButton.new()
	fs.name = "Fullscreen"
	fs.size = Vector2(220, 56)
	fs.position = Vector2(480, 40)
	add_child(fs)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		start()


## 플레이 테스트 요약 + JSON을 클립보드로.
func copy_results() -> void:
	DisplayServer.clipboard_set(Playtest.report_text())
	_copied.text = "복사했어요. 카톡에 붙여 보내 주세요"
	_copied_left = 3.0


func start() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)


func _process(delta: float) -> void:
	_time += delta
	for i in _runners.size():
		var t: float = _time - ECHO_DELAY * i
		var x: float = _run_x(t)
		var facing_left: bool = _run_x(t + 0.02) < x
		_runners[i].position = Vector2(x, RUN_Y - _hop(t))
		_runners[i].scale.x = -1.5 if facing_left else 1.5
	_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)
	_copied_left = maxf(_copied_left - delta, 0.0)
	_copied.visible = _copied_left > 0.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG)
	# 로고: 고스트 4색이 조금씩 늦게 따라오는 잔상 + 흰 본문
	var base := Vector2(0, 410)
	for i in range(4, 0, -1):
		var off := Vector2(-sin(_time * 1.3 - i * 0.5) * 6.0 * i, i * 5.0)
		draw_string(_font, base + off, LOGO_TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 118, Color(Palette.ghost(i), 0.45))
	draw_string(_font, base, LOGO_TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 118, Palette.ME)
	# 연출 바닥선
	draw_line(Vector2(80, RUN_Y + 48), Vector2(640, RUN_Y + 48), Palette.WALL_LINE, 3.0)


## 왕복(4초 주기, 양 끝에서 잠깐 멈춤).
func _run_x(t: float) -> float:
	var p: float = fposmod(t, 4.0) / 4.0
	var k: float = clampf(abs(p * 2.0 - 1.0) * 1.15 - 0.075, 0.0, 1.0)
	return lerpf(RUN_RIGHT, RUN_LEFT, k)


## 가운데쯤에서 한 번 점프.
func _hop(t: float) -> float:
	var p: float = fposmod(t, 2.0)
	return 90.0 * maxf(0.0, sin(clampf((p - 0.8) / 0.45, 0.0, 1.0) * PI))


func _add_label(text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
