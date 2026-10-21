class_name Fx
extends Node
## 화면 연출 담당(게임 로직과 무관, 그리는 일은 _process에서만):
## - 루프 리셋(종료·실패·처음부터·되돌리기·덮어쓰기): 0.5초 되감기 셰이더 + 화면 흔들림
## - 패러독스 붕괴: 그 자리에 글리치 셰이더 고스트
## - CLEAR: 출구 플래시 → 모든 루프 경로를 점선으로 겹쳐 그림

signal rewind_started
signal clear_shown

const REWIND_SECONDS: float = 0.5
const SHAKE_SECONDS: float = 0.3
const GLITCH_SECONDS: float = 0.45
const PATH_REVEAL_SECONDS: float = 1.0

@export var loop_manager: LoopManager
@export var camera: Camera2D

var _rewind_left: float = 0.0
var _shake_left: float = 0.0
var _pending_rewind: bool = false
var _pending_clear: bool = false
var _pending_glitches: Array[Ghost] = []
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _clear_paths: ClearPaths
var _base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = load("res://assets/fx/rewind.gdshader")
	_overlay.material = _overlay_mat
	_overlay.visible = false
	layer.add_child(_overlay)
	_clear_paths = ClearPaths.new()
	_clear_paths.visible = false
	_clear_paths.z_index = 20
	add_child(_clear_paths)
	if loop_manager != null:
		loop_manager.loop_ended.connect(func(_i: int) -> void: _pending_rewind = true)
		loop_manager.loop_failed.connect(func() -> void: _pending_rewind = true)
		loop_manager.stage_restarted.connect(func() -> void: _pending_rewind = true)
		loop_manager.ghosts_changed.connect(func() -> void: _pending_rewind = true)
		loop_manager.stage_cleared.connect(func() -> void: _pending_clear = true)


func _process(delta: float) -> void:
	_watch_ghosts()
	if _pending_rewind:
		_pending_rewind = false
		_rewind_left = REWIND_SECONDS
		_shake_left = SHAKE_SECONDS
		_clear_paths.visible = false
		rewind_started.emit()
	if _pending_clear:
		_pending_clear = false
		_show_clear()
	for g: Ghost in _pending_glitches:
		if is_instance_valid(g):
			_spawn_glitch(g)
	_pending_glitches.clear()
	_rewind_left = maxf(_rewind_left - delta, 0.0)
	_overlay.visible = _rewind_left > 0.0
	_overlay_mat.set_shader_parameter("amount", _rewind_left / REWIND_SECONDS)
	_shake_left = maxf(_shake_left - delta, 0.0)
	if camera != null:
		var k: float = _shake_left / SHAKE_SECONDS
		var t: float = Time.get_ticks_msec() * 0.001
		camera.offset = _base_offset + Vector2(sin(t * 90.0), cos(t * 71.0)) * 6.0 * k * k


## 카메라 기본 오프셋(릴스 모드가 바꾼다). 흔들림은 이 위에 더한다.
func set_base_offset(o: Vector2) -> void:
	_base_offset = o


func rewind_active() -> bool:
	return _rewind_left > 0.0


func _watch_ghosts() -> void:
	if loop_manager == null:
		return
	for g: Ghost in loop_manager.ghosts():
		if not g.has_meta("fx_watched"):
			g.set_meta("fx_watched", true)
			g.collapsed.connect(func() -> void: _pending_glitches.append(g))


func _spawn_glitch(g: Ghost) -> void:
	var s := GlitchSprite.new()
	s.setup(Palette.ghost(g.number), g.global_position, GLITCH_SECONDS)
	add_child(s)


func _show_clear() -> void:
	var level: Level = (get_parent() as Node).get("level")
	if level != null and level.exit != null:
		var ring := FlashRing.new()
		ring.position = level.exit.global_position + Vector2(0, -50)
		add_child(ring)
	var paths: Array = []
	for g: Ghost in loop_manager.ghosts():
		paths.append({"color": Palette.ghost(g.number), "frames": g.frames()})
	paths.append({"color": Palette.ME, "frames": loop_manager.player.recording.duplicate()})
	_clear_paths.show_paths(paths, PATH_REVEAL_SECONDS)
	clear_shown.emit()
