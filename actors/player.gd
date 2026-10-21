class_name Player
extends CharacterBody2D
## 지금의 나. 좌우 이동·점프를 하고, 매 물리 틱 위치를 녹화한다.

@export var spawn_point: Marker2D
@export var move_speed: float = 360.0
@export var jump_velocity: float = 900.0
@export var gravity: float = 2400.0
@export var max_fall_speed: float = 1400.0
@export var coyote_seconds: float = 0.1
@export var jump_buffer_seconds: float = 0.1

## 고스트가 그대로 따라갈 경로. 입력이 아니라 위치를 남겨야 환경이 조금 달라져도 경로가 어긋나지 않는다.
## 항목: {"pos": Vector2, "flip": bool, "interact": bool}
var recording: Array[Dictionary] = []

# 시간은 초가 아니라 틱으로 센다(결정론). 초 단위 export 값은 _ready에서 한 번만 틱으로 바꾼다.
var _coyote_ticks: int = 0
var _jump_buffer_ticks: int = 0
var _coyote_ticks_left: int = 0
var _jump_buffer_ticks_left: int = 0
var _flip: bool = false

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("resettable")
	_coyote_ticks = int(coyote_seconds * Engine.physics_ticks_per_second)
	_jump_buffer_ticks = int(jump_buffer_seconds * Engine.physics_ticks_per_second)
	reset()


func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed
	if direction != 0.0:
		_flip = direction < 0.0
		_visual.scale.x = -1.0 if _flip else 1.0

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	_update_jump()
	move_and_slide()

	# 상호작용은 "누른 순간"만 남긴다. 누르고 있는 동안 계속 true면 고스트가 레버를 매 틱 다시 당기게 된다.
	recording.append({
		"pos": global_position,
		"flip": _flip,
		"interact": Input.is_action_just_pressed("interact"),
	})


func reset() -> void:
	recording.clear()
	velocity = Vector2.ZERO
	# 루프 직전에 눌러 둔 점프가 다음 루프 첫 틱에 새어 나가지 않도록 버퍼도 비운다.
	_coyote_ticks_left = 0
	_jump_buffer_ticks_left = 0
	_flip = false
	_visual.scale.x = 1.0
	if spawn_point == null:
		push_warning("Player.spawn_point가 비어 있어 현재 위치에서 시작한다.")
		return
	global_position = spawn_point.global_position


func _update_jump() -> void:
	if is_on_floor():
		_coyote_ticks_left = _coyote_ticks
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_ticks_left = _jump_buffer_ticks

	if _coyote_ticks_left > 0 and _jump_buffer_ticks_left > 0:
		velocity.y = -jump_velocity
		_coyote_ticks_left = 0
		_jump_buffer_ticks_left = 0

	# 판정한 뒤에 깎아야 바닥을 떠난 뒤·버튼을 누른 뒤 정확히 N틱 동안 점프가 허용된다.
	if not is_on_floor() and _coyote_ticks_left > 0:
		_coyote_ticks_left -= 1
	if _jump_buffer_ticks_left > 0:
		_jump_buffer_ticks_left -= 1
