class_name Level
extends Node2D
## 레벨 씬 루트. Main이 여기서 스폰 위치와 출구를 받아 Player·LoopManager에 연결한다.

@export var spawn_point: Marker2D
@export var exit: Exit
