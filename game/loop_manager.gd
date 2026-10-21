class_name LoopManager
extends Node
## 루프 시간을 물리 틱으로 세고, 시간 초과·end_loop·restart_stage 때 방 전체를 리셋한다.
##
## 실행 순서: process_physics_priority = 100 으로 Player(-10)보다 "나중에" 돈다.
## 그래야 한 틱 안에서 Player 이동·녹화 → 틱 카운트·종료 판정 → 리셋 순서가 되어,
## 루프가 끝나는 순간 recording 길이가 정확히 loop_ticks가 되고
## loop_ended를 받는 쪽(다음 단계의 고스트 생성)이 리셋 전 녹화를 읽을 수 있다.

## 루프가 끝나고 리셋 직전에 발생. 인자는 증가된 뒤의(= 다음) 루프 번호.
signal loop_ended(loop_index: int)
## Shift+R로 스테이지를 처음부터 다시 시작했을 때(리셋 직전) 발생.
signal stage_restarted

@export var loop_seconds: float = 10.0

var loop_ticks: int = 0
## 이번 루프에서 지난 물리 틱 수 (0 ~ loop_ticks).
var tick: int = 0
var loop_index: int = 1


func _ready() -> void:
	loop_ticks = int(loop_seconds * Engine.physics_ticks_per_second)


func _physics_process(_delta: float) -> void:
	# restart_stage(Shift+R)를 먼저 본다. end_loop는 exact match라 Shift+R에는 반응하지 않지만,
	# 순서를 정해 두면 한 틱에 두 처리가 겹칠 일이 없다.
	if Input.is_action_just_pressed("restart_stage"):
		restart_stage()
		return

	tick += 1
	if tick >= loop_ticks or Input.is_action_just_pressed("end_loop", true):
		end_loop()


func end_loop() -> void:
	loop_index += 1
	loop_ended.emit(loop_index)
	_reset_all()


func restart_stage() -> void:
	loop_index = 1
	stage_restarted.emit()
	_reset_all()


func remaining_ticks() -> int:
	return maxi(loop_ticks - tick, 0)


func _reset_all() -> void:
	tick = 0
	get_tree().call_group("resettable", "reset")
