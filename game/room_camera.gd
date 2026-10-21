class_name RoomCamera
extends Camera2D
## 방(Level.room_rect, 벽 안쪽)을 화면의 정해진 영역에 맞추는 카메라. Main·리플레이 씬이 같이 쓴다.
## 몸·이동·점프 수치는 그대로 두고 레벨 기하를 작게 짠 뒤 줌으로 키워 보이게 한다(BACKLOG "캐릭터 2배" 결정).
##
## 화면 규칙(뷰포트 720x1280): HUD y 0~240, 릴스 텍스트 y 240~300, 방 y 300~1030, 그 아래는 캡션·타임라인·터치 버튼.
## 화면 전환만 하므로 게임 로직과 무관하다(_process에서 매 프레임 맞춘다).

## 보통 화면에서 방이 들어갈 영역.
const NORMAL_TARGET: Rect2 = Rect2(0, 300, 720, 730)
## 릴스 모드: 오른쪽 아래 세로 띠(좋아요 버튼)를 피한다.
const REELS_TARGET: Rect2 = Rect2(24, 300, 588, 730)
const SCREEN_CENTER: Vector2 = Vector2(360, 640)

## 릴스 모드면 줌 상한 없이 REELS_TARGET에 꽉 차게, 아니면 레벨의 camera_zoom(넘치면 들어갈 만큼 줄임).
var reels: bool = false


func _process(_delta: float) -> void:
	apply()


func apply() -> void:
	var room: Rect2 = _room_rect()
	if room.size.x <= 0.0 or room.size.y <= 0.0:
		return
	var target: Rect2 = REELS_TARGET if reels else NORMAL_TARGET
	var z: float = fit_zoom(room, target)
	if not reels:
		var level: Level = _level()
		z = minf(z, level.camera_zoom if level != null else 1.0)
	zoom = Vector2(z, z)
	# 화면 = (월드 - 카메라 위치) * z + 화면 중심  →  방 중심이 목표 영역 중심에 오도록
	position = room.get_center() - (target.get_center() - SCREEN_CENTER) / z


## room이 target 안에 다 들어가는 가장 큰 줌.
static func fit_zoom(room: Rect2, target: Rect2) -> float:
	return minf(target.size.x / room.size.x, target.size.y / room.size.y)


## 방 내부가 화면에서 차지하는 사각형(테스트·확인용).
func room_screen_rect() -> Rect2:
	var room: Rect2 = _room_rect()
	var xf: Transform2D = get_viewport().get_canvas_transform()
	return Rect2(xf * room.position, room.size * xf.get_scale())


func _level() -> Level:
	return get_parent().get("level") as Level


func _room_rect() -> Rect2:
	var level: Level = _level()
	return level.room_rect() if level != null else Rect2()
