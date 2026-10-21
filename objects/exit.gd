class_name Exit
extends Area2D
## 지금의 나(Player)가 닿으면 스테이지 클리어. mask가 player뿐이라 고스트는 감지조차 하지 않는다.
##
## 실행 순서: process_physics_priority = 30. LoopManager(100)보다 먼저 돌아,
## 출구에 닿은 틱에 시간 초과가 겹쳐도 클리어가 우선한다.

signal reached

var _player_inside: bool = false
## Area2D 겹침 목록은 리셋 뒤 물리 스텝이 한 번 돌고 나서야 새 위치를 반영한다(측정: 틱 끝 리셋이면 다음 1틱이 낡음).
## 그 사이에 판정하면 리셋 전 위치의 바디 때문에 판이 눌리거나 출구에서 다시 CLEAR가 된다.
## 리셋이 틱 중간·시작에 일어나도 맞도록 리셋된 물리 프레임에서 2프레임이 지날 때까지 겹침을 쓰지 않는다.
var _reset_frame: int = -100


func _ready() -> void:
	add_to_group("resettable")


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() - _reset_frame < 2:
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
	_reset_frame = Engine.get_physics_frames()
