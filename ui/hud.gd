class_name Hud
extends CanvasLayer
## 남은 시간 바, "LOOP n" / "나 ×n" 두 줄, 고스트 슬롯, 루프 타임라인, 클리어 표시.
## 게임 상태는 읽기만 하므로 _process(연출)에서 갱신한다.

@export var loop_manager: LoopManager
@export var player: Player
@export var warning_seconds: float = 3.0
@export var bar_color: Color = Color(0.9, 0.9, 0.95, 1)
@export var warning_color: Color = Color(1, 0.35, 0.3, 1)

var _warning_ticks: int = 0

@onready var _fill: ColorRect = $TimeBar/Fill
@onready var _loop_label: Label = $LoopLabel
@onready var _count_label: Label = $CountLabel
@onready var _clear_panel: Control = $ClearPanel
@onready var _slots: GhostSlots = $GhostSlots
@onready var _timeline: Timeline = $Timeline


func _ready() -> void:
	_warning_ticks = int(warning_seconds * Engine.physics_ticks_per_second)
	_slots.loop_manager = loop_manager
	_timeline.loop_manager = loop_manager
	_timeline.player = player


func _process(_delta: float) -> void:
	if loop_manager == null or loop_manager.loop_ticks <= 0:
		return
	var remaining: int = loop_manager.remaining_ticks()
	# 왼쪽 끝을 기준으로 줄어들도록 크기 대신 scale.x를 쓴다(앵커·오프셋을 건드리지 않음).
	_fill.scale.x = float(remaining) / float(loop_manager.loop_ticks)
	_fill.color = warning_color if remaining <= _warning_ticks else bar_color
	_loop_label.text = "LOOP %d" % loop_manager.loop_index
	_count_label.text = "나 ×%d" % (loop_manager.ghost_count() + 1)
	if loop_manager.overwrite_target > 0:
		_count_label.text += "  ·  %d번 다시 찍기" % loop_manager.overwrite_target
	_clear_panel.visible = loop_manager.cleared
