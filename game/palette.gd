class_name Palette
extends RefCounted
## "NEON LOOP" 비주얼 팔레트. 색은 여기서만 정하고 모든 연출 코드가 가져다 쓴다.

const BG: Color = Color("#0A0C14")
const ROOM: Color = Color("#10131F")
const GRID: Color = Color(1, 1, 1, 0.03)
const GRID_STEP: float = 24.0
const WALL_LINE: Color = Color("#3B4773")
const ME: Color = Color("#F4F5FA")
## 고스트 고정색: 1 파랑, 2 주황, 3 초록, 4 보라(릴스 시리즈 내내 바꾸지 않는다).
const GHOSTS: Array[Color] = [Color("#4FA3FF"), Color("#FF9A3D"), Color("#4ADE80"), Color("#B47CFF")]
const SIGNAL: Color = Color("#FFD23F")
const DOOR: Color = Color("#FF4D6D")
const EXIT: Color = Color("#5EF2C2")
const SUB_TEXT: Color = Color("#8B93AD")
## 고스트 몸 채움 투명도.
const GHOST_FILL_ALPHA: float = 0.28


static func ghost(number: int) -> Color:
	return GHOSTS[(number - 1) % GHOSTS.size()]
