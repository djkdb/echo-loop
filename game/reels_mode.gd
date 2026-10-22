class_name ReelsMode
extends Node
## 릴스 모드(F9): HUD·타임라인·조작 UI를 숨기고, 방을 화면 y 300~1030 안에 꽉 차게 맞추고,
## 릴스 텍스트 자리(y 240~300)에 한 줄을 띄운다. 보통 화면과 같은 세로 규칙이다(RoomCamera).
## 위쪽 0~240은 인스타 상단 UI, 아래 약 250px은 캡션, 오른쪽 아래 세로 띠는 좋아요 버튼이 덮으므로
## 방이 그 영역에 걸치지 않게 한다. 화면 전환이라 게임 로직과 무관하다.

## 방이 들어갈 화면 영역(뷰포트 720x1280 기준).
const ROOM_TARGET: Rect2 = RoomCamera.REELS_TARGET
## 상단 텍스트 슬롯(릴스 텍스트 자리).
const TEXT_SLOT: Rect2 = Rect2(0, 240, 720, 60)
const MAX_FONT_SIZE: int = 50
const MIN_FONT_SIZE: int = 26

## 상단 문구. 비우면 "10초 전의 나 × n"(n = 고스트 수 + 1)을 자동으로 쓴다.
@export var text: String = ""
@export var loop_manager: LoopManager
@export var camera: RoomCamera
@export var hud: CanvasLayer

var active: bool = false

var _layer: CanvasLayer
var _label: Label


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	_layer.visible = false
	add_child(_layer)
	_label = Label.new()
	_label.position = TEXT_SLOT.position
	_label.size = TEXT_SLOT.size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_font_override("font", load("res://assets/fonts/hud_font.tres"))
	_label.add_theme_font_size_override("font_size", MAX_FONT_SIZE)
	_label.add_theme_color_override("font_color", Palette.ME)
	_label.add_theme_color_override("font_outline_color", Palette.BG)
	_label.add_theme_constant_override("outline_size", 12)
	_layer.add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reels_mode"):
		set_active(not active)


func set_active(on: bool) -> void:
	active = on
	_layer.visible = on
	# 켜는 순간부터 문구가 보이게(이 노드가 멈춰 있는 렌더 장면에서도)
	_set_text(text if text != "" else _auto_text())
	if hud != null:
		hud.visible = not on
	_apply_camera()


func _process(_delta: float) -> void:
	if not active:
		return
	_set_text(text if text != "" else _auto_text())
	_apply_camera()


## 문구가 한 줄에 다 들어가도록 글자 크기를 줄인다(최대 50, 최소 26).
func _set_text(t: String) -> void:
	if _label.text == t:
		return
	_label.text = t
	var font: Font = _label.get_theme_font("font")
	var fs: int = MAX_FONT_SIZE
	while fs > MIN_FONT_SIZE and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > TEXT_SLOT.size.x - 32.0:
		fs -= 2
	_label.add_theme_font_size_override("font_size", fs)


func _auto_text() -> String:
	if loop_manager == null or loop_manager.loop_ticks <= 0:
		return ""
	var secs: int = roundi(float(loop_manager.loop_ticks) / float(Engine.physics_ticks_per_second))
	return "%d초 전의 나 × %d" % [secs, loop_manager.ghost_count() + 1]


## 방 내부가 화면에서 차지하는 사각형(테스트·확인용).
func room_screen_rect() -> Rect2:
	return camera.room_screen_rect() if camera != null else Rect2()


func _apply_camera() -> void:
	if camera != null:
		camera.reels = active
		camera.apply()
