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
	_level_root.add_child(level)
	_player.spawn_point = level.spawn_point
	level.exit.reached.connect(_loop_manager.clear_stage)
	# 레벨이 붙은 뒤에 시작해야 Player가 이 레벨의 SpawnPoint에서, 이 레벨의 루프 설정으로 시작한다.
	_loop_manager.start_level(level)
