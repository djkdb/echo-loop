class_name ColorDoor
extends Door
## 색 문: 파랑은 지금의 나(Player)만 막아 고스트만 지나가고, 주황은 고스트만 막아 지금의 나만 지나간다.
## 충돌 레이어로 구분한다: 파랑 = player_barrier(5, Player mask에만 있음), 주황 = ghost_barrier(6, Ghost mask에만 있음).
## 주황 문은 고스트에게 지형이라, 지금의 내가 지나간 녹화를 재생하면 그 문에서 붕괴한다(역할 분리 강제).
## sources·inverted·끼임 방지는 Door와 같다(신호가 없으면 계속 닫혀 있다).

enum DoorColor { BLUE, ORANGE }

const LAYER_PLAYER_BARRIER: int = 1 << 4
const LAYER_GHOST_BARRIER: int = 1 << 5

@export var door_color: DoorColor = DoorColor.BLUE


func _ready() -> void:
	collision_layer = LAYER_PLAYER_BARRIER if door_color == DoorColor.BLUE else LAYER_GHOST_BARRIER
	tint = Palette.GHOSTS[0] if door_color == DoorColor.BLUE else Palette.GHOSTS[1]
	super._ready()
