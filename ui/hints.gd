class_name Hints
extends Label
## 첫 플레이 안내(HUD 안, 화면 y 240~300 릴스 텍스트 자리). 1-1~1-3에서만 그 방의 핵심 한 줄을 띄우고,
## 그 스테이지를 한 번 깨면(Progress 기록) 다시 띄우지 않는다. 아무 입력 없이 시간 초과가 2번 연속 나면
## "언제든 루프를 끝낼 수 있다"를 한 번 띄운다(Progress 플래그). HUD가 숨는 릴스 모드·리플레이 렌더에는 나오지 않는다.
## 화면 표시만 하므로 _process에서 갱신한다(게임 로직 없음).

const IDLE_FLAG: String = "hint_idle_seen"
## 시간 초과가 이만큼 연속으로 아무 입력 없이 나면 안내.
const IDLE_LOOPS: int = 2
## {end}는 루프 끝내는 방법(키보드: R로 / 터치: 시간 바를 길게 눌러)으로 바뀐다.
const STAGE_HINTS: Dictionary = {
	"level_1_1": ["{end} 루프를 끝내면 방금의 내가 남아요", "과거의 나를 밟고 올라가 보세요"],
	"level_1_2": ["과거의 나를 압력판 위에 세워 두고 문을 지나가세요"],
	"level_1_3": ["과거의 나를 낮은 단 위에 세우면 더 높이 닿아요"],
}

var loop_manager: LoopManager
var stage_id: String = ""

var _input_this_loop: bool = false
var _idle_loops: int = 0
## 시간 초과 안내를 띄우는 중(다음 입력이 들어오거나 루프가 끝날 때까지).
var _idle_showing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	position = Vector2(20, 240)
	size = Vector2(680, 60)
	add_theme_font_override("font", load("res://assets/fonts/hud_font.tres"))
	add_theme_font_size_override("font_size", 26)
	add_theme_color_override("font_color", Palette.EXIT)
	add_theme_color_override("font_outline_color", Palette.BG)
	add_theme_constant_override("outline_size", 8)
	if loop_manager != null:
		loop_manager.loop_ended.connect(_on_loop_ended)
		loop_manager.loop_failed.connect(_on_loop_reset)
		loop_manager.stage_restarted.connect(_on_loop_reset)
		loop_manager.ghosts_changed.connect(_on_loop_reset)


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and (event as InputEventKey).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	if pressed:
		_input_this_loop = true
		if _idle_showing:
			_idle_showing = false


func _process(_delta: float) -> void:
	text = current_text()
	visible = text != ""


## 지금 띄울 문구(없으면 "").
func current_text() -> String:
	if loop_manager == null or loop_manager.cleared:
		return ""
	if _idle_showing:
		return "%s 언제든 루프를 끝낼 수 있어요" % ("시간 바를 길게 누르면" if TouchControls.enabled() else "R을 누르면")
	var lines: Array = STAGE_HINTS.get(stage_id, [])
	if lines.is_empty() or Progress.is_cleared(stage_id):
		return ""
	var i: int = mini(loop_manager.ghost_count(), lines.size() - 1)
	return (lines[i] as String).replace("{end}", "시간 바를 길게 눌러" if TouchControls.enabled() else "R로")


func _on_loop_ended(_loop_index: int) -> void:
	# loop_ended는 리셋 직전에 나오므로 tick이 아직 이번 루프 값이다(시간 초과면 loop_ticks).
	var timed_out: bool = loop_manager.tick >= loop_manager.loop_ticks
	_idle_loops = _idle_loops + 1 if timed_out and not _input_this_loop else 0
	_idle_showing = false
	if _idle_loops >= IDLE_LOOPS and not Progress.has_flag(IDLE_FLAG):
		_idle_showing = true
		Progress.set_flag(IDLE_FLAG)
	_input_this_loop = false


func _on_loop_reset() -> void:
	_idle_loops = 0
	_input_this_loop = false
