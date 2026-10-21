extends Node2D
## 레벨 씬을 Level 컨테이너에 불러와 Player·LoopManager에 연결하고 스테이지를 시작한다.

@export var level_scene: PackedScene

var level: Level

@onready var _level_root: Node2D = $Level
@onready var _player: Player = $Player
@onready var _loop_manager: LoopManager = $LoopManager


func _ready() -> void:
	load_level(level_scene)


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
