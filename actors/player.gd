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

const HOLD_BLOCKED_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump"]

## 고스트가 그대로 따라갈 경로. 입력이 아니라 위치를 남겨야 환경이 조금 달라져도 경로가 어긋나지 않는다.
## 항목: {"pos": Vector2, "flip": bool, "interact": bool}
var recording: Array[Dictionary] = []

# 시간은 초가 아니라 틱으로 센다(결정론). 초 단위 export 값은 _ready에서 한 번만 틱으로 바꾼다.
var _coyote_ticks: int = 0
var _jump_buffer_ticks: int = 0
var _coyote_ticks_left: int = 0
var _jump_buffer_ticks_left: int = 0
var _flip: bool = false
## 리셋 순간 누르고 있던 키. 한 번 뗄 때까지 무시해서 루프 끝의 입력이 다음 루프로 새지 않게 한다.
var _held_on_reset: Array[StringName] = []
## 루프 시작 때 같은 스폰에서 겹쳐 있는 고스트. 겹친 채로 충돌하면 밀려나므로 떨어질 때까지 통과시킨다.
var _passthrough_ghosts: Array[Ghost] = []

@onready var _visual: Node2D = $Visual
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("resettable")
	_coyote_ticks = int(coyote_seconds * Engine.physics_ticks_per_second)
	_jump_buffer_ticks = int(jump_buffer_seconds * Engine.physics_ticks_per_second)
	# 첫 reset()은 Main이 레벨을 붙이고 SpawnPoint를 넘겨준 뒤 restart_stage로 한다.


func _physics_process(delta: float) -> void:
	_unblock_released_actions()
	_restore_separated_ghosts()
	var direction: float = _action_strength(&"move_right") - _action_strength(&"move_left")
	velocity.x = direction * move_speed
	if direction != 0.0:
		_flip = direction < 0.0
		_visual.scale.x = -1.0 if _flip else 1.0

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	var jumped: bool = _update_jump()
	move_and_slide()

	# 상호작용은 "누른 순간"만 남긴다. 누르고 있는 동안 계속 true면 고스트가 레버를 매 틱 다시 당기게 된다.
	var interacted: bool = Input.is_action_just_pressed("interact")
	if interacted:
		_interact_with_overlapping()
	# jump는 재생에 쓰지 않고 루프 타임라인 표시용이다.
	recording.append({
		"pos": global_position,
		"flip": _flip,
		"interact": interacted,
		"jump": jumped,
	})


## 끼임 판정 등에서 쓰는 몸 모양(Player·고스트 공용 body_shape.tres).
func body_shape() -> Shape2D:
	return _shape.shape


func reset() -> void:
	recording.clear()
	velocity = Vector2.ZERO
	# 루프 직전에 눌러 둔 점프가 다음 루프 첫 틱에 새어 나가지 않도록 버퍼도 비운다.
	_coyote_ticks_left = 0
	_jump_buffer_ticks_left = 0
	_flip = false
	_visual.scale.x = 1.0
	_held_on_reset.clear()
	for action: StringName in HOLD_BLOCKED_ACTIONS:
		if Input.is_action_pressed(action):
			_held_on_reset.append(action)
	_pass_through_all_ghosts()
	if spawn_point == null:
		push_warning("Player.spawn_point가 비어 있어 현재 위치에서 시작한다.")
	else:
		global_position = spawn_point.global_position
	_refresh_contact_state()


## 겹쳐 있는 레버·시한 버튼을 당긴다. 고스트도 녹화된 interact 틱에 같은 방식으로 부른다.
func _interact_with_overlapping() -> void:
	for node: Node in get_tree().get_nodes_in_group("interactables"):
		if (node as Area2D).overlaps_body(self):
			node.interact()


## 이번 틱에 점프했으면 true.
func _update_jump() -> bool:
	if is_on_floor():
		_coyote_ticks_left = _coyote_ticks
	if Input.is_action_just_pressed("jump") and not _held_on_reset.has(&"jump"):
		_jump_buffer_ticks_left = _jump_buffer_ticks

	var jumped: bool = false
	if _coyote_ticks_left > 0 and _jump_buffer_ticks_left > 0:
		velocity.y = -jump_velocity
		_coyote_ticks_left = 0
		_jump_buffer_ticks_left = 0
		jumped = true

	# 판정한 뒤에 깎아야 바닥을 떠난 뒤·버튼을 누른 뒤 정확히 N틱 동안 점프가 허용된다.
	if not is_on_floor() and _coyote_ticks_left > 0:
		_coyote_ticks_left -= 1
	if _jump_buffer_ticks_left > 0:
		_jump_buffer_ticks_left -= 1
	return jumped


func _unblock_released_actions() -> void:
	for action: StringName in _held_on_reset.duplicate():
		if not Input.is_action_pressed(action):
			_held_on_reset.erase(action)


func _action_strength(action: StringName) -> float:
	if _held_on_reset.has(action):
		return 0.0
	return Input.get_action_strength(action)


## CharacterBody2D는 직전 move_and_slide의 바닥·플랫폼 정보를 다음 move_and_slide에서 쓴다.
## 리셋으로 순간이동하면 그 정보가 낡아서, 루프 끝에 밟고 있던 고스트가 리셋 위치로 순간이동하는
## 속도를 플랫폼 속도로 받아 튕겨 나간다. 플랫폼 속도를 무시한 채 제자리 이동을 한 번 해서 새로 계산한다.
## (덤으로 첫 틱의 is_on_floor()가 이전 루프 상태에 좌우되지 않게 된다.)
func _refresh_contact_state() -> void:
	var floor_layers: int = platform_floor_layers
	var wall_layers: int = platform_wall_layers
	platform_floor_layers = 0
	platform_wall_layers = 0
	velocity = Vector2.ZERO
	move_and_slide()
	velocity = Vector2.ZERO
	platform_floor_layers = floor_layers
	platform_wall_layers = wall_layers


func _pass_through_all_ghosts() -> void:
	for ghost: Ghost in _passthrough_ghosts:
		if is_instance_valid(ghost):
			remove_collision_exception_with(ghost)
	_passthrough_ghosts.clear()
	# call_group 순서상 고스트가 아직 리셋되기 전일 수 있어 여기서는 겹침을 판정할 수 없다.
	# 일단 전부 통과시키고, 매 틱 _restore_separated_ghosts에서 떨어진 고스트부터 다시 충돌시킨다.
	for node: Node in get_tree().get_nodes_in_group("ghosts"):
		var ghost: Ghost = node as Ghost
		add_collision_exception_with(ghost)
		_passthrough_ghosts.append(ghost)


func _restore_separated_ghosts() -> void:
	if _passthrough_ghosts.is_empty():
		return
	var my_rect: Rect2 = _shape.shape.get_rect()
	my_rect.position += global_position
	for ghost: Ghost in _passthrough_ghosts.duplicate():
		if not is_instance_valid(ghost):
			_passthrough_ghosts.erase(ghost)
			continue
		# Player와 고스트는 같은 body_shape.tres를 쓰므로 같은 사각형으로 겹침을 본다.
		# 고스트가 먼저 돌아 replay_position은 이번 스텝에 갈 곳, global_position은 지금 물리 공간에 있는 곳이다.
		# 둘 다에서 떨어져야 다시 충돌시켜도 밀려나지 않는다.
		var base_rect: Rect2 = _shape.shape.get_rect()
		var now_rect: Rect2 = Rect2(base_rect.position + ghost.global_position, base_rect.size)
		var next_rect: Rect2 = Rect2(base_rect.position + ghost.replay_position, base_rect.size)
		if not my_rect.intersects(now_rect) and not my_rect.intersects(next_rect):
			remove_collision_exception_with(ghost)
			_passthrough_ghosts.erase(ghost)
