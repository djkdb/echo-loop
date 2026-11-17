class_name Replay
extends Node2D
## 리플레이 씬: user://replays/<stage>.json 을 불러와 모든 루프를 고스트로 겹쳐 재생하고, 루프 끝마다 처음으로 돌아간다.
## Player·LoopManager 없이 돌므로 판·문·레버 등 오브젝트는 고스트에만 반응한다(녹화와 같은 결과).
##
## 명령줄(Movie Maker 렌더 예):
##   godot --path . --write-movie replay.avi --fixed-fps 60 res://game/replay.tscn -- --stage=level_1_2 --loops=1 --reels
##   --stage=<id>  리플레이 이름(기본 stage_id)   --loops=<n>  n번 재생하고 종료(0 = 무한)   --reels  릴스 모드로
##   --solution  user://replays 대신 개발자 정답(solutions/<id>.json)을 재생(릴스 "정답편")
##   --text=<문구>  릴스 모드 상단 문구   --trim  마지막 루프(지금의 나)가 끝나고 0.75초 뒤에 루프를 끝낸다
##   --speed=<n>  n배속(1~4). 틱 수를 n배로 늘리고 time_scale도 n배로 해 틱당 delta가 그대로라 재생 결과가 같다.
##   --seamless  마지막 재생이 끝나면 처음 장면으로 되돌린 프레임을 찍고 끝낸다(영상 끝이 처음과 이어짐)

@export var stage_id: String = "level_1_2"
@export var loops: int = 0
@export var reels: bool = false
@export var solution: bool = false
@export var text: String = ""
@export var trim: bool = false
@export var seamless: bool = false
@export_range(1, 4) var speed: int = 1
## 게임 안에서 연 리플레이(CLEAR 패널 버튼): Esc·E·탭으로 스테이지 선택 화면에 돌아가고 안내 한 줄을 띄운다.
@export var in_game: bool = false

## 게임 씬이 리플레이 씬으로 바꾸기 전에 넣는 요청({stage, speed}). 명령줄 인자 대신 쓴다.
static var request: Dictionary = {}
const BASE_TICKS: int = 60
const SELECT_SCENE: String = "res://ui/stage_select.tscn"

## --trim: 마지막 녹화가 끝난 뒤 이만큼 더 보여 주고 루프를 끝낸다.
const TRIM_TAIL_TICKS: int = 45
var _quit_in: int = -1
@export var ghost_scene: PackedScene

var level: Level
var loop_ticks: int = 0
var tick: int = 0
var played: int = 0
var ghosts: Array[Ghost] = []

@onready var _level_root: Node2D = $Level
@onready var _ghosts_root: Node2D = $Ghosts


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage_id = arg.trim_prefix("--stage=")
		elif arg.begins_with("--loops="):
			loops = int(arg.trim_prefix("--loops="))
		elif arg == "--reels":
			reels = true
		elif arg == "--solution":
			solution = true
		elif arg.begins_with("--text="):
			text = arg.trim_prefix("--text=")
		elif arg == "--trim":
			trim = true
		elif arg == "--seamless":
			seamless = true
		elif arg.begins_with("--speed="):
			speed = clampi(int(arg.trim_prefix("--speed=")), 1, 4)
	if not request.is_empty():
		stage_id = request.get("stage", stage_id)
		speed = int(request.get("speed", 2))
		in_game = true
		request = {}
	process_physics_priority = 100
	var doc: Dictionary = ReplayIO.load_solution(stage_id) if solution else ReplayIO.load_run(stage_id)
	if doc.is_empty():
		push_warning("리플레이 %s가 없다: 먼저 그 스테이지를 CLEAR할 것." % (ReplayIO.solution_path(stage_id) if solution else ReplayIO.path_for(stage_id)))
		return
	start(doc)
	if in_game:
		_add_overlay()


## 불러온 리플레이로 재생을 시작한다(테스트도 직접 부른다).
func start(doc: Dictionary) -> void:
	level = (load(doc["level"]) as PackedScene).instantiate() as Level
	_level_root.add_child(level)
	if level.exit != null:
		level.exit.process_mode = Node.PROCESS_MODE_DISABLED
	loop_ticks = int(float(doc["loop_seconds"]) * Engine.physics_ticks_per_second)
	var runs: Array = doc["runs"]
	if trim and not runs.is_empty():
		loop_ticks = mini(loop_ticks, (runs[-1] as Array).size() + TRIM_TAIL_TICKS)
	for i in runs.size():
		var g: Ghost = ghost_scene.instantiate() as Ghost
		g.me_style = i == runs.size() - 1
		g.setup(runs[i], i + 1)
		_ghosts_root.add_child(g)
		ghosts.append(g)
	var reels_node: ReelsMode = get_node_or_null("ReelsMode")
	if reels_node != null:
		reels_node.text = text if text != "" else "%d초 전의 나 × %d" % [roundi(float(doc["loop_seconds"])), runs.size()]
		reels_node.set_active(reels)
	get_tree().call_group("resettable", "reset")
	set_speed(speed)


## n배속. 레벨이 다 준비된 뒤(시한 버튼·발판이 틱 수를 읽은 뒤)에 바꿔야 틱당 동작이 같다.
func set_speed(n: int) -> void:
	speed = clampi(n, 1, 4)
	Engine.physics_ticks_per_second = BASE_TICKS * speed
	Engine.time_scale = float(speed)


func _exit_tree() -> void:
	# 게임으로 돌아가면 원래 속도(규칙 2: 틱은 60/초)
	Engine.physics_ticks_per_second = BASE_TICKS
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not in_game:
		return
	var back: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if back:
		get_viewport().set_input_as_handled()
		Progress.pending_stage = stage_id
		get_tree().change_scene_to_file(SELECT_SCENE)


func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var l := Label.new()
	l.text = "리플레이 ×%d  ·  Esc / E / 탭: 돌아가기" % speed
	l.position = Vector2(0, 1180)
	l.size = Vector2(720, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://assets/fonts/hud_font.tres"))
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Palette.SUB_TEXT)
	layer.add_child(l)
	var reels_node: ReelsMode = get_node_or_null("ReelsMode")
	if reels_node != null:
		reels_node.text = "%s  %s" % [Stages.find(stage_id).get("code", ""), Stages.find(stage_id).get("title", "")]
		reels_node.set_active(true)


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	if _quit_in >= 0:
		_quit_in -= 1
		if _quit_in < 0:
			get_tree().quit()
		return
	tick += 1
	if tick >= loop_ticks:
		tick = 0
		played += 1
		if loops > 0 and played >= loops:
			if seamless:
				# 처음 장면으로 돌려 놓고 두 프레임 더 찍은 뒤 끝낸다
				get_tree().call_group("resettable", "reset")
				_quit_in = 2
			else:
				get_tree().quit()
			return
		get_tree().call_group("resettable", "reset")
