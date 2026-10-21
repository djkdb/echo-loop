extends Node2D
## 레벨 씬을 Level 컨테이너에 불러와 Player·LoopManager에 연결하고 스테이지를 시작한다.
## 스테이지 선택 화면에서 들어오면(Progress.pending_stage) 그 스테이지를 열고, Esc로 선택 화면,
## CLEAR 뒤 E로 다음 스테이지. CLEAR 때 리플레이와 최소 고스트 기록(별점)을 저장한다.

const SELECT_SCENE: String = "res://ui/stage_select.tscn"
const GAME_SCENE: String = "res://game/main.tscn"

@export var level_scene: PackedScene

var level: Level
## 스테이지 선택 화면에서 들어왔으면 true. 테스트·에디터에서 이 씬을 바로 열면 false(메뉴 이동 없음).
var from_menu: bool = false

@onready var _level_root: Node2D = $Level
@onready var _player: Player = $Player
@onready var _loop_manager: LoopManager = $LoopManager
@onready var _hud: Hud = $HUD


func _ready() -> void:
	if Progress.pending_stage != "" and Stages.index_of(Progress.pending_stage) >= 0:
		level_scene = load(Stages.path(Progress.pending_stage))
		from_menu = true
	_hud.menu_mode = from_menu
	load_level(level_scene)


func _unhandled_input(event: InputEvent) -> void:
	if not from_menu:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(SELECT_SCENE)
	elif _loop_manager.cleared and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		next_stage()


## CLEAR 뒤 다음 스테이지로(마지막이면 선택 화면).
func next_stage() -> void:
	var next: String = Stages.next_of(stage_id())
	if next == "" or not Progress.is_unlocked(next):
		get_tree().change_scene_to_file(SELECT_SCENE)
		return
	Progress.pending_stage = next
	get_tree().change_scene_to_file(GAME_SCENE)


func load_level(scene: PackedScene) -> void:
	if level != null:
		_level_root.remove_child(level)
		level.queue_free()
	level = scene.instantiate() as Level
	# 레벨을 붙이기 전에 Player를 새 스폰으로 옮긴다. 이전 레벨 위치에 있는 채로 붙이면 그 자리에 겹친
	# 출구·판이 물리 스텝 두 번 뒤까지 낡은 겹침으로 남아 시작하자마자 CLEAR된다.
	# (첫 시작 때는 물리 서버가 아직 씬의 Player 위치를 쓰므로 main.tscn에서 Player를 방 밖 멀리 둔다.)
	var spawn: Node2D = level.get_node_or_null("SpawnPoint")
	if spawn != null:
		_player.global_position = spawn.position
	_level_root.add_child(level)
	_player.spawn_point = level.spawn_point
	level.exit.reached.connect(_loop_manager.clear_stage)
	if not _loop_manager.stage_cleared.is_connected(_save_replay):
		_loop_manager.stage_cleared.connect(_save_replay)
		_loop_manager.stage_cleared.connect(_record_clear)
	_hud.stage_id = stage_id()
	# 레벨이 붙은 뒤에 시작해야 Player가 이 레벨의 SpawnPoint에서, 이 레벨의 루프 설정으로 시작한다.
	_loop_manager.start_level(level)


## 스테이지 id = 레벨 씬 파일 이름(확장자 제외). 리플레이 파일 이름에 쓴다.
func stage_id() -> String:
	return level.scene_file_path.get_file().get_basename() if level != null else ""


## CLEAR한 순간의 모든 루프(고스트 번호 순 + 마지막 나)를 리플레이로 저장한다.
func _save_replay() -> void:
	var runs: Array = []
	for ghost: Ghost in _loop_manager.ghosts():
		runs.append(ghost.frames())
	runs.append(_player.recording)
	ReplayIO.save_run(stage_id(), level.scene_file_path, level.loop_seconds, runs)


## 이 스테이지를 이번에 몇 명의 고스트로 깼는지 남긴다(최소 기록만 저장, 별점은 Stages가 계산).
func _record_clear() -> void:
	Progress.record_clear(stage_id(), _loop_manager.ghost_count())
