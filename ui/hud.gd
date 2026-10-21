class_name Hud
extends CanvasLayer
## 남은 시간 바, "LOOP n" / "나 ×n" 두 줄, 고스트 슬롯, 루프 타임라인, 클리어 표시.
## 게임 상태는 읽기만 하므로 _process(연출)에서 갱신한다.

@export var loop_manager: LoopManager
@export var player: Player
@export var warning_seconds: float = 3.0
@export var bar_color: Color = Palette.ME
@export var warning_color: Color = Palette.DOOR

## 지금 스테이지 id(CLEAR 별점 계산용, Main이 넣는다).
var stage_id: String = ""
## 스테이지 선택 화면에서 들어왔는지(CLEAR 안내 문구가 달라진다).
var menu_mode: bool = false

var _warning_ticks: int = 0
var _last_tick_second: int = -1

@onready var _fill: ColorRect = $TimeBar/Fill
@onready var _loop_label: Label = $LoopLabel
@onready var _count_label: Label = $CountLabel
@onready var _clear_panel: Control = $ClearPanel
@onready var _slots: GhostSlots = $GhostSlots
@onready var _timeline: Timeline = $Timeline
@onready var _hint_label: Label = $ClearPanel/HintLabel

var _clear_stars: StarIcons
var _clear_record: Label
var _clear_shown: bool = false


func _ready() -> void:
	_warning_ticks = int(warning_seconds * Engine.physics_ticks_per_second)
	_slots.loop_manager = loop_manager
	_timeline.loop_manager = loop_manager
	_timeline.player = player
	# CLEAR 패널 아래에 별점과 기록 한 줄(코드로 붙인다: 위치만 정하면 되는 단순한 조각)
	_clear_stars = StarIcons.new()
	_clear_stars.star_size = 30.0
	_clear_stars.gap = 12.0
	_clear_stars.position = Vector2(0, 690)
	_clear_stars.size = Vector2(720, 70)
	_clear_panel.add_child(_clear_stars)
	_clear_record = _hint_label.duplicate() as Label
	_clear_record.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_clear_record.position = Vector2(0, 760)
	_clear_record.size = Vector2(720, 44)
	_clear_record.add_theme_font_size_override("font_size", 30)
	_clear_record.add_theme_color_override("font_color", Palette.SIGNAL)
	_clear_panel.add_child(_clear_record)
	_hint_label.offset_top = 175.0
	_hint_label.offset_bottom = 225.0
	# 모바일 터치 버튼(터치 화면에서만 보인다). HUD 안이라 릴스 모드에서 HUD와 함께 숨는다.
	var touch := TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)


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
	if loop_manager.cleared and not _clear_shown:
		_show_clear_result()
	_clear_shown = loop_manager.cleared


func _show_clear_result() -> void:
	var ghosts: int = loop_manager.ghost_count()
	var s: Dictionary = Stages.find(stage_id)
	if s.is_empty():
		_clear_stars.count = 0
		_clear_record.text = "고스트 %d명" % ghosts
	else:
		_clear_stars.count = Stages.stars_for(ghosts, s["max"], s["record"])
		_clear_record.text = "고스트 %d명 · ★3 기준 %d명 이하" % [ghosts, s["record"]]
	_hint_label.text = "R 다시 · E 다음 스테이지 · Esc 선택" if menu_mode else "R: 다시 시작"
