extends Node2D
## 리플레이 씬: user://replays/<stage>.json 을 불러와 모든 루프를 고스트로 겹쳐 재생하고, 루프 끝마다 처음으로 돌아간다.
## Player·LoopManager 없이 돌므로 판·문·레버 등 오브젝트는 고스트에만 반응한다(녹화와 같은 결과).
##
## 명령줄(Movie Maker 렌더 예):
##   godot --path . --write-movie replay.avi --fixed-fps 60 res://game/replay.tscn -- --stage=level_1_2 --loops=1 --reels
##   --stage=<id>  리플레이 이름(기본 stage_id)   --loops=<n>  n번 재생하고 종료(0 = 무한)   --reels  릴스 모드로
##   --solution  user://replays 대신 개발자 정답(solutions/<id>.json)을 재생(릴스 "정답편")

@export var stage_id: String = "level_1_2"
@export var loops: int = 0
@export var reels: bool = false
@export var solution: bool = false
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
	process_physics_priority = 100
	var doc: Dictionary = ReplayIO.load_solution(stage_id) if solution else ReplayIO.load_run(stage_id)
	if doc.is_empty():
		push_warning("리플레이 %s가 없다: 먼저 그 스테이지를 CLEAR할 것." % (ReplayIO.solution_path(stage_id) if solution else ReplayIO.path_for(stage_id)))
		return
	start(doc)


## 불러온 리플레이로 재생을 시작한다(테스트도 직접 부른다).
func start(doc: Dictionary) -> void:
	level = (load(doc["level"]) as PackedScene).instantiate() as Level
	_level_root.add_child(level)
	if level.exit != null:
		level.exit.process_mode = Node.PROCESS_MODE_DISABLED
	loop_ticks = int(float(doc["loop_seconds"]) * Engine.physics_ticks_per_second)
	var runs: Array = doc["runs"]
	for i in runs.size():
		var g: Ghost = ghost_scene.instantiate() as Ghost
		g.me_style = i == runs.size() - 1
		g.setup(runs[i], i + 1)
		_ghosts_root.add_child(g)
		ghosts.append(g)
	var reels_node: ReelsMode = get_node_or_null("ReelsMode")
	if reels_node != null:
		reels_node.text = "%d초 전의 나 × %d" % [roundi(float(doc["loop_seconds"])), runs.size()]
		reels_node.set_active(reels)
	get_tree().call_group("resettable", "reset")


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	tick += 1
	if tick >= loop_ticks:
		tick = 0
		played += 1
		if loops > 0 and played >= loops:
			get_tree().quit()
			return
		get_tree().call_group("resettable", "reset")
