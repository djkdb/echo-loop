class_name Ghost
extends AnimatableBody2D
## 과거의 나. 녹화된 위치를 틱마다 그대로 따라가고, 길이 막히면 패러독스로 붕괴한다.
##
## 실행 순서: process_physics_priority = -20 으로 Player(-10)보다 먼저 돈다.
## sync_to_physics라 위치는 어차피 모든 _physics_process가 끝난 뒤 물리 스텝에서 반영되지만,
## 붕괴(충돌 끄기)는 즉시 적용되므로 먼저 돌아야 "T틱에 붕괴 = T틱부터 못 밟음"이 된다.

## 녹화 경로가 지형에 막혀 이번 루프에서 붕괴했을 때.
signal collapsed

## 기획서 고정색: 1 파랑, 2 주황, 3 초록, 4 보라(Palette.GHOSTS, 릴스 시리즈 내내 바꾸지 않는다).
const COLORS: Array[Color] = Palette.GHOSTS

## 녹화 위치까지 이만큼(px) 이상 못 가야 "막힘"으로 본다. 녹화 위치는 표면의 safe margin(0.08px) 안쪽에
## 걸칠 수 있어서(예: 내려온 발판에 바닥 쪽으로 눌린 Player), 0 기준이면 환경이 같아도 붕괴가 난다.
const BLOCK_TOLERANCE: float = 0.5
## supports_jump에서 "같은 높이"로 보는 오차(px). 서 있는 녹화도 표면 safe margin 때문에 아주 조금 흔들릴 수 있다.
const GROUNDED_EPSILON: float = 0.05

var number: int = 1
var alive: bool = true
## 덮어쓰기 대상으로 골라져 이번 루프는 빠져 있는 상태(숨김·충돌 없음·누르지 않음).
var benched: bool = false
## 이번 루프에서 붕괴한 틱(루프 타임라인 표시용). 붕괴 안 했으면 -1.
var collapsed_at_tick: int = -1
## 리플레이에서 "지금의 나" 루프를 고스트로 재생할 때: 흰 불투명 몸, 번호 배지 없음.
var me_style: bool = false
## 이번 틱에 가기로 한 위치. sync_to_physics라 global_position은 물리 스텝 뒤에야 따라오므로,
## 리셋 직후 겹침 판정처럼 "지금 어디로 가 있는가"가 필요하면 이 값을 쓴다.
var replay_position: Vector2 = Vector2.ZERO

var _frames: Array[Dictionary] = []
## 이번 루프에서 처리한 틱 수. T번째 틱(1부터)에 frames[T - 1]로 간다.
var _tick: int = 0
var _last_fx_tick: int = -1

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Node2D = $Visual
@onready var _body: CharacterVisual = $Visual/Body
@onready var _badge: Polygon2D = $Badge
@onready var _number_label: Label = $Badge/NumberLabel


## 트리에 넣기 전에 호출한다(덮어쓰기 때는 트리 안에서 다시 부르고 바로 reset된다).
## frames는 이미 깊은 복사된 녹화여야 한다(Player가 리셋 때 원본을 비움).
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
	var color: Color = Palette.ME if me_style else Palette.ghost(number)
	_body.body_color = color
	_body.eye_color = Palette.BG if me_style else color
	if me_style:
		_body.fill_alpha = 1.0
		_body.outline_width = 0.0
		_badge.visible = false
		$Trail.visible = false
	_badge.polygon = _badge_circle(11.0)
	_badge.color = color
	_number_label.text = str(number)
	($Trail as Node).set("ghost", self)


func _process(_delta: float) -> void:
	# 녹화의 점프·착지 순간에 Player와 같은 찌그러짐(연출 전용)
	if not alive or _tick < 2 or _tick > _frames.size():
		return
	var f: Dictionary = _frames[_tick - 1]
	if _tick != _last_fx_tick:
		_last_fx_tick = _tick
		if f.get("jump", false):
			_body.pulse(Vector2(0.85, 1.15), 0.12)
		elif _tick >= 3:
			var vy_prev: float = (_frames[_tick - 2]["pos"] as Vector2).y - (_frames[_tick - 3]["pos"] as Vector2).y
			var vy_now: float = (f["pos"] as Vector2).y - (_frames[_tick - 2]["pos"] as Vector2).y
			if vy_prev > 4.0 and absf(vy_now) < 0.5:
				_body.pulse(Vector2(1.15, 0.85), 0.08)


## 지금까지 처리한 틱 수(잔상·연출이 녹화의 어디를 재생 중인지 알 때 쓴다).
func current_tick() -> int:
	return _tick


func _badge_circle(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _physics_process(_delta: float) -> void:
	if not alive or _frames.is_empty():
		return
	# 녹화보다 루프가 길면(R로 일찍 끝낸 녹화) 마지막 위치에 실체를 유지한 채 멈춘다.
	var playing: bool = _tick < _frames.size()
	var frame: Dictionary = _frames[mini(_tick, _frames.size() - 1)]
	_tick += 1
	var target: Vector2 = frame["pos"]
	# sync_to_physics에서 global_position은 직전 물리 스텝 결과(= 지금 실제로 있는 곳)다.
	var motion: Vector2 = target - global_position
	# 녹화 당시엔 지나간 길이 지금 지형(mask = world + 주황 문)에 막혔는지 이동 전에 검사한다.
	if motion != Vector2.ZERO:
		var hit := KinematicCollision2D.new()
		if test_move(global_transform, motion, hit) and hit.get_remainder().length() > BLOCK_TOLERANCE:
			collapse()
			return
	global_position = target
	replay_position = target
	_visual.scale.x = -1.0 if frame["flip"] else 1.0
	# 멈춰 선 뒤에는 마지막 프레임의 interact를 매 틱 반복하지 않는다.
	if playing and frame["interact"]:
		for node: Node in get_tree().get_nodes_in_group("interactables"):
			if (node as Area2D).overlaps_body(self):
				node.interact()


## 이번 틱에 위에 선 Player가 점프할 수 있는가: 녹화에서 이번 틱 위치가 앞뒤 틱보다 낮지 않을 때(서 있거나 막 착지)만.
## 점프 중·낙하 중·발판에 실려 가는 고스트를 발판 삼아 뛰면 고스트 점프 높이가 그대로 더해져
## (실측: 올라탄 채 꼭대기에서 뛰면 352px) 고스트 1명이 탑 2단보다 높이 닿는다. 높이 퍼즐(2-2 탑 쌓기)이
## 성립하도록 막는다. 녹화를 미리 다 알고 있어서 "다음 틱"도 볼 수 있다(결정론 유지).
func supports_jump() -> bool:
	if not alive or _frames.size() < 2 or _tick >= _frames.size():
		return true
	var i: int = maxi(_tick - 1, 0)
	var y: float = (_frames[i]["pos"] as Vector2).y
	var prev_y: float = (_frames[maxi(i - 1, 0)]["pos"] as Vector2).y
	var next_y: float = (_frames[i + 1]["pos"] as Vector2).y
	return y >= prev_y - GROUNDED_EPSILON and y >= next_y - GROUNDED_EPSILON


## 끼임 판정 등에서 쓰는 몸 모양(Player·고스트 공용 body_shape.tres).
## 녹화(읽기 전용으로 쓸 것). 루프 타임라인이 점프·interact 틱을 읽는다.
func frames() -> Array[Dictionary]:
	return _frames


func body_shape() -> Shape2D:
	return _shape.shape


func reset() -> void:
	_tick = 0
	collapsed_at_tick = -1
	alive = not benched
	visible = not benched
	_shape.disabled = benched
	if _frames.is_empty():
		return
	global_position = _frames[0]["pos"]
	replay_position = _frames[0]["pos"]
	_visual.scale.x = -1.0 if _frames[0]["flip"] else 1.0


## 패러독스 붕괴. 경로가 막혔을 때 스스로, 레이저에 닿았을 때 레이저가 부른다.
func collapse() -> void:
	if not alive:
		return
	alive = false
	collapsed_at_tick = _tick
	hide()
	# 숨기기만 하면 보이지 않는 발판이 남는다. 같은 틱에 Player가 밟지 못하도록 충돌도 즉시 끈다.
	_shape.disabled = true
	collapsed.emit()
