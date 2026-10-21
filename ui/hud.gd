class_name Hud
extends CanvasLayer
## 남은 시간 바, "LOOP n" / "나 ×n" 두 줄, 고스트 슬롯, 루프 타임라인, 클리어 표시.
## 게임 상태는 읽기만 하므로 _process(연출)에서 갱신한다.

@export var loop_manager: LoopManager
@export var player: Player
@export var warning_seconds: float = 3.0
@export var bar_color: Color = Palette.ME
@export var warning_color: Color = Palette.DOOR

var _warning_ticks: int = 0
var _last_tick_second: int = -1

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
	# 마지막 3초: 매초 시작에 막대가 번쩍이고 똑딱 소리가 난다.
	if remaining <= _warning_ticks and remaining > 0 and not loop_manager.cleared:
		var sec: int = ceili(float(remaining) / float(Engine.physics_ticks_per_second))
		if sec != _last_tick_second:
			_last_tick_second = sec
			Sfx.play("tick", 0.0, 1.0 if sec % 2 == 1 else 0.8)
	else:
		_last_tick_second = -1
	if remaining <= _warning_ticks and remaining > 0:
		var phase: float = float(remaining % Engine.physics_ticks_per_second) / float(Engine.physics_ticks_per_second)
		_fill.modulate = Color(1, 1, 1, 1).lerp(Color(1.6, 1.6, 1.6, 1), clampf((phase - 0.8) * 5.0, 0.0, 1.0))
	else:
		_fill.modulate = Color.WHITE
	_loop_label.text = "LOOP %d" % loop_manager.loop_index
	_count_label.text = "나 ×%d" % (loop_manager.ghost_count() + 1)
	if loop_manager.overwrite_target > 0:
		_count_label.text += "  ·  %d번 다시 찍기" % loop_manager.overwrite_target
	_clear_panel.visible = loop_manager.cleared
