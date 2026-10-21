class_name PressurePlate
extends Area2D
## 누군가 올라가 있는 동안만 on. 겹친 바디 수로 판정해 Player와 고스트를 똑같이 다룬다(규칙 8).
##
## 실행 순서: process_physics_priority = 10. 바디들이 움직인 뒤, 받는 쪽(문, 20)보다 먼저 판정한다.
## 겹침 목록은 직전 물리 스텝 결과라 Player·고스트 모두 같은 틱 지연으로 반영된다(결정론).

signal toggled(on: bool)

var is_on: bool = false

## Area2D 겹침 목록은 리셋 뒤 물리 스텝이 한 번 돌고 나서야 새 위치를 반영한다(측정: 틱 끝 리셋이면 다음 1틱이 낡음).
## 그 사이에 판정하면 리셋 전 위치의 바디 때문에 판이 눌리거나 출구에서 다시 CLEAR가 된다.
## 리셋이 틱 중간·시작에 일어나도 맞도록 리셋된 물리 프레임에서 2프레임이 지날 때까지 겹침을 쓰지 않는다.
var _reset_frame: int = -100

@onready var _visual: Node2D = $Visual
@onready var _glow: Sprite2D = $Glow

var _flash: float = 0.0


func _ready() -> void:
	add_to_group("resettable")


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() - _reset_frame < 2:
		return
	_set_on(_pressing_body_count() > 0)


func reset() -> void:
	_set_on(false)
	_reset_frame = Engine.get_physics_frames()


func _pressing_body_count() -> int:
	var count: int = 0
	for body: Node2D in get_overlapping_bodies():
		if is_weight(body):
			count += 1
	return count


## 판을 누르는(문 끼임에도 쓰는) 몸: Player, 살아 있는 고스트, 상자. mask에 world가 있어(상자 감지)
## 판에 닿은 바닥·벽도 겹침 목록에 들어오므로 종류로 거른다. 붕괴한 고스트는 사라진 것이라 세지 않는다.
static func is_weight(body: Node2D) -> bool:
	if body is Ghost:
		return (body as Ghost).alive
	return body is Player or body is Box


func _set_on(on: bool) -> void:
	if is_on == on:
		return
	is_on = on
	if on:
		_flash = 0.1
	toggled.emit(on)


## 연출: 눌리면 2px 내려앉고 0.1초 번쩍인 뒤 은은한 글로우를 유지한다.
func _process(delta: float) -> void:
	if _flash >= 0.1:
		Sfx.play("plate")
	_flash = maxf(_flash - delta, 0.0)
	_visual.position.y = 2.0 if is_on else 0.0
	var a: float = 0.0
	if is_on:
		a = 0.35 + 0.65 * (_flash / 0.1)
	_glow.modulate.a = a
