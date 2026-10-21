class_name Level
extends Node2D
## 레벨 씬 루트. Main이 여기서 스폰 위치와 출구를 받아 Player·LoopManager에 연결한다.
## 루프 길이·고스트 상한은 스테이지마다 다르므로(기획서: 6~15초, 1~4명) 레벨이 갖고, LoopManager가 읽는다.

@export var spawn_point: Marker2D
@export var exit: Exit
@export var loop_seconds: float = 10.0
@export var max_ghosts: int = 2
