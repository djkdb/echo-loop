extends Node
## 릴스 "문제편" 렌더 씬(개발 도구, 내보내기에서 제외). 릴스 모드로 방 전체를 2초 보여 준 뒤, 고스트 없이 정답의
## 마지막 루프(지금의 나) 입력을 그대로 넣어 첫 루프에서 실패하는 장면(되감기)까지 찍고, "정답은 다음 릴스"를 1.5초 띄우고 끝낸다.
##   godot --path . --write-movie problem.avi --fixed-fps 60 res://tools/reels_problem.tscn -- --stage=level_2_2 --text=... --next-text=...

const SHOW_TICKS: int = 120
const NEXT_TICKS: int = 90
## 입력이 끝난 뒤 이만큼 기다렸다가 루프를 실패로 끝낸다(고스트를 남기지 않아 마지막 장면에 고스트가 없다).
const IDLE_TAIL_TICKS: int = 45
## 루프가 끝난 뒤 되감기 연출을 보여 주는 시간.
const REWIND_TICKS: int = 36

var stage_id: String = "level_1_1"
var text: String = ""
var next_text: String = "정답은 다음 릴스"

var _main: Node
var _lm: LoopManager
var _inputs: String = ""
var _phase: String = "show"
var _t: int = 0
var _ended: bool = false
var _next_label: Label


func _ready() -> void:
	process_physics_priority = -100
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage_id = arg.trim_prefix("--stage=")
		elif arg.begins_with("--text="):
			text = arg.trim_prefix("--text=")
		elif arg.begins_with("--next-text="):
			next_text = arg.trim_prefix("--next-text=")
	var doc: Dictionary = ReplayIO.load_solution(stage_id)
	if doc.is_empty():
		push_error("정답 리플레이가 없다: %s" % ReplayIO.solution_path(stage_id))
		get_tree().quit(1)
		return
	_inputs = (doc["inputs"] as Array)[-1]
	Progress.pending_stage = ""
	# 힌트·기록이 실제 저장 파일을 건드리지 않게
	Progress.path = "user://reels_progress.json"
	Progress.best = {}
	Playtest.path = "user://reels_playtest.json"
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	_main.level_scene = load(doc["level"])
	add_child(_main)
	_lm = _main.get_node("LoopManager")
	_lm.loop_ended.connect(func(_i: int) -> void: _ended = true)
	_lm.loop_failed.connect(func() -> void: _ended = true)
	var reels: ReelsMode = _main.get_node("ReelsMode")
	reels.text = text
	reels.set_active(true)
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_next_label = Label.new()
	_next_label.position = Vector2(0, 560)
	_next_label.size = Vector2(720, 160)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_label.add_theme_font_override("font", load("res://assets/fonts/hud_font.tres"))
	_next_label.add_theme_font_size_override("font_size", 64)
	_next_label.add_theme_color_override("font_color", Palette.SIGNAL)
	_next_label.add_theme_color_override("font_outline_color", Palette.BG)
	_next_label.add_theme_constant_override("outline_size", 16)
	_next_label.text = next_text
	_next_label.visible = false
	layer.add_child(_next_label)


func _physics_process(_delta: float) -> void:
	_t += 1
	match _phase:
		"show":
			if _t >= SHOW_TICKS:
				_phase = "play"
				_t = 0
				# 시작할 때 쌓인 되감기 연출은 버린다(멈춰 있던 동안의 것이라 실패 장면 앞에 나오면 안 됨)
				_main.get_node("Fx").set("_pending_rewind", false)
				_main.process_mode = Node.PROCESS_MODE_INHERIT
		"play":
			var i: int = _lm.tick
			_apply(_inputs[i] if i < _inputs.length() else "0")
			if i >= _inputs.length() + IDLE_TAIL_TICKS or i >= _lm.loop_ticks - 1:
				_lm.fail_loop()
			if _ended or _lm.cleared:
				_apply("0")
				_phase = "rewind"
				_t = 0
		"rewind":
			if _t >= REWIND_TICKS:
				_phase = "next"
				_t = 0
				_main.process_mode = Node.PROCESS_MODE_DISABLED
				_next_label.visible = true
		"next":
			if _t >= NEXT_TICKS:
				get_tree().quit()


func _apply(code: String) -> void:
	var bits: int = code.hex_to_int()
	var actions: Array[String] = ["move_left", "move_right", "jump", "interact"]
	for k in actions.size():
		if bits & (1 << k):
			Input.action_press(actions[k])
		else:
			Input.action_release(actions[k])
