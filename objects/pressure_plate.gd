class_name PressurePlate
extends Area2D
## 누군가 올라가 있는 동안만 on. 겹친 바디 수로 판정해 Player와 고스트를 똑같이 다룬다(규칙 8).
##
## 실행 순서: process_physics_priority = 10. 바디들이 움직인 뒤, 받는 쪽(문, 20)보다 먼저 판정한다.
## 겹침 목록은 직전 물리 스텝 결과라 Player·고스트 모두 같은 틱 지연으로 반영된다(결정론).

signal toggled(on: bool)

var is_on: bool = false

## Area2D의 겹침 목록은 리셋 직후 첫 틱에 아직 리셋 전 위치 기준이다(측정).
## 그 틱을 그대로 쓰면 이전 루프 끝에 판 위에 있던 바디 때문에 새 루프 첫 틱에 판이 눌린다.
var _ignore_stale_overlaps: bool = false

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("resettable")


func _physics_process(_delta: float) -> void:
	if _ignore_stale_overlaps:
		_ignore_stale_overlaps = false
		return
	_set_on(_pressing_body_count() > 0)


func reset() -> void:
	_set_on(false)
	_ignore_stale_overlaps = true


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
	# 눌린 게 보이도록 살짝 내려앉힌다.
	_visual.position.y = 4.0 if on else 0.0
	toggled.emit(on)
