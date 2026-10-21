class_name ReelsMode
extends Node
## 릴스 모드(F9): HUD·타임라인·조작 UI를 숨기고, 방을 화면 y 300~1030 안에 꽉 차게 맞추고,
## 상단 y 120~280에 텍스트 한 줄을 띄운다. 아래 약 250px은 인스타 캡션, 오른쪽 아래 세로 띠는
## 좋아요 버튼이 덮으므로 방이 그 영역에 걸치지 않게 한다. 화면 전환이라 게임 로직과 무관하다.

## 방이 들어갈 화면 영역(뷰포트 720x1280 기준).
const ROOM_TARGET: Rect2 = Rect2(24, 300, 588, 730)
## 상단 텍스트 슬롯.
const TEXT_SLOT: Rect2 = Rect2(24, 120, 672, 160)
const SCREEN_CENTER: Vector2 = Vector2(360, 640)

## 상단 문구. 비우면 "10초 전의 나 × n"(n = 고스트 수 + 1)을 자동으로 쓴다.
@export var text: String = ""
@export var loop_manager: LoopManager
@export var camera: Camera2D
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
	_label.add_theme_font_size_override("font_size", 64)
	_label.add_theme_color_override("font_color", Palette.ME)
	_label.add_theme_color_override("font_outline_color", Palette.BG)
	_label.add_theme_constant_override("outline_size", 14)
	_layer.add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reels_mode"):
		set_active(not active)


func set_active(on: bool) -> void:
	active = on
	_layer.visible = on
	if hud != null:
		hud.visible = not on
	_apply_camera()


func _process(_delta: float) -> void:
	if not active:
		return
	_label.text = text if text != "" else _auto_text()
	_apply_camera()


func _auto_text() -> String:
	if loop_manager == null or loop_manager.loop_ticks <= 0:
		return ""
	var secs: int = roundi(float(loop_manager.loop_ticks) / float(Engine.physics_ticks_per_second))
	return "%d초 전의 나 × %d" % [secs, loop_manager.ghost_count() + 1]


## 방 내부가 화면에서 차지하는 사각형(테스트·확인용).
func room_screen_rect() -> Rect2:
	var room: Rect2 = _room_rect()
	var xf: Transform2D = camera.get_viewport().get_canvas_transform() if camera != null else Transform2D.IDENTITY
	return Rect2(xf * room.position, room.size * xf.get_scale())


func _apply_camera() -> void:
	if camera == null:
		return
	if not active:
		camera.zoom = Vector2.ONE
		camera.position = SCREEN_CENTER
		return
	var room: Rect2 = _room_rect()
	var z: float = minf(ROOM_TARGET.size.x / room.size.x, ROOM_TARGET.size.y / room.size.y)
	camera.zoom = Vector2(z, z)
	# 화면 = (월드 - 카메라 위치) * z + 화면 중심  →  방 중심이 목표 영역 중심에 오도록
	camera.position = room.get_center() - (ROOM_TARGET.get_center() - SCREEN_CENTER) / z


func _room_rect() -> Rect2:
	var level: Level = get_parent().get("level")
	return level.room_rect() if level != null else Rect2(0, 0, 720, 1280)
