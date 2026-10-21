class_name Ghost
extends AnimatableBody2D
## 과거의 나. 녹화된 위치를 틱마다 그대로 따라가고, 길이 막히면 패러독스로 붕괴한다.
##
## 실행 순서: process_physics_priority = -20 으로 Player(-10)보다 먼저 돈다.
## sync_to_physics라 위치는 어차피 모든 _physics_process가 끝난 뒤 물리 스텝에서 반영되지만,
## 붕괴(충돌 끄기)는 즉시 적용되므로 먼저 돌아야 "T틱에 붕괴 = T틱부터 못 밟음"이 된다.

## 녹화 경로가 지형에 막혀 이번 루프에서 붕괴했을 때.
signal collapsed

const COLORS: Array[Color] = [Color(0.3, 0.6, 1.0, 1), Color(1.0, 0.6, 0.2, 1)]

var number: int = 1
var alive: bool = true
## 이번 틱에 가기로 한 위치. sync_to_physics라 global_position은 물리 스텝 뒤에야 따라오므로,
## 리셋 직후 겹침 판정처럼 "지금 어디로 가 있는가"가 필요하면 이 값을 쓴다.
var replay_position: Vector2 = Vector2.ZERO

var _frames: Array[Dictionary] = []
## 이번 루프에서 처리한 틱 수. T번째 틱(1부터)에 frames[T - 1]로 간다.
var _tick: int = 0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Node2D = $Visual
@onready var _body: Polygon2D = $Visual/Body
@onready var _number_label: Label = $NumberLabel


## 트리에 넣기 전에 호출한다. frames는 이미 깊은 복사된 녹화여야 한다(Player가 리셋 때 원본을 비움).
func setup(frames: Array[Dictionary], ghost_number: int) -> void:
	_frames = frames
	number = ghost_number
	# top_level이라 position이 곧 전역 좌표. 트리에 들어가기 전에 시작 위치에 두면
	# 첫 진입이 순간이동(거대한 kinematic 속도)으로 계산되지 않는다.
	if not _frames.is_empty():
		position = _frames[0]["pos"]
		replay_position = position


func _ready() -> void:
	# 아키텍처 규칙 5: 위치를 물리 스텝에 동기화해야 위에 선 Player가 플랫폼처럼 같이 움직인다.
	sync_to_physics = true
	add_to_group("resettable")
	# Player가 루프 시작 때 겹친 고스트를 찾아 잠시 통과시키는 데 쓴다.
	add_to_group("ghosts")
	_body.color = COLORS[(number - 1) % COLORS.size()]
	_number_label.text = str(number)


func _physics_process(_delta: float) -> void:
	if not alive or _frames.is_empty():
		return
	# 녹화보다 루프가 길면(R로 일찍 끝낸 녹화) 마지막 위치에 실체를 유지한 채 멈춘다.
	var frame: Dictionary = _frames[mini(_tick, _frames.size() - 1)]
	_tick += 1
	var target: Vector2 = frame["pos"]
	# sync_to_physics에서 global_position은 직전 물리 스텝 결과(= 지금 실제로 있는 곳)다.
	var motion: Vector2 = target - global_position
	# 녹화 당시엔 지나간 길이 지금 지형(mask = world)에 막혔는지 이동 전에 검사한다.
	if motion != Vector2.ZERO and test_move(global_transform, motion):
		_collapse()
		return
	global_position = target
	replay_position = target
	_visual.scale.x = -1.0 if frame["flip"] else 1.0


func reset() -> void:
	_tick = 0
	alive = true
	show()
	_shape.disabled = false
	if _frames.is_empty():
		return
	global_position = _frames[0]["pos"]
	replay_position = _frames[0]["pos"]
	_visual.scale.x = -1.0 if _frames[0]["flip"] else 1.0


func _collapse() -> void:
	alive = false
	hide()
	# 숨기기만 하면 보이지 않는 발판이 남는다. 같은 틱에 Player가 밟지 못하도록 충돌도 즉시 끈다.
	_shape.disabled = true
	collapsed.emit()
