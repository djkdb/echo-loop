class_name Exit
extends Area2D
## 지금의 나(Player)가 닿으면 스테이지 클리어. mask가 player뿐이라 고스트는 감지조차 하지 않는다.
##
## 실행 순서: process_physics_priority = 30. LoopManager(100)보다 먼저 돌아,
## 출구에 닿은 틱에 시간 초과가 겹쳐도 클리어가 우선한다.

signal reached

var _player_inside: bool = false
## Area2D의 겹침 목록은 리셋 직후 첫 틱에 아직 리셋 전 위치 기준이다(측정).
## 그 틱을 쓰면 출구에서 R을 눌러 다시 시작해도 바로 또 CLEAR가 된다.
var _ignore_stale_overlaps: bool = false


func _ready() -> void:
	add_to_group("resettable")


func _physics_process(_delta: float) -> void:
	if _ignore_stale_overlaps:
		_ignore_stale_overlaps = false
		return
	var inside: bool = false
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			inside = true
			break
	# 닿는 순간 한 번만 알린다.
	if inside and not _player_inside:
		reached.emit()
	_player_inside = inside


func reset() -> void:
	_player_inside = false
	_ignore_stale_overlaps = true
