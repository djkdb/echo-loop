class_name Stages
extends RefCounted
## 스테이지 목록(스테이지 선택 화면·별점·다음 스테이지가 읽는다). 레벨 씬을 열지 않고 목록을 그리려고 따로 둔다.
## max = 레벨의 max_ghosts, record = 개발자 최소 기록(solutions/<id>.json의 고스트 수, ★3 기준).
## 레벨이나 정답을 고치면 여기도 맞춘다(tests/cases/test_80_stages.gd가 어긋남을 잡는다).

const CHAPTER_NAMES: Array[String] = ["과거의 나", "장치", "에코"]

const LIST: Array[Dictionary] = [
	{"id": "level_1_1", "code": "1-1", "title": "첫 걸음", "element": "이동 · 점프 · 루프", "max": 1, "record": 1},
	{"id": "level_1_2", "code": "1-2", "title": "문지기", "element": "압력판 · 문", "max": 1, "record": 1},
	{"id": "level_1_3", "code": "1-3", "title": "디딤돌", "element": "고스트 밟기", "max": 1, "record": 1},
	{"id": "level_1_4", "code": "1-4", "title": "두 개의 문", "element": "레버", "max": 1, "record": 1},
	{"id": "level_1_5", "code": "1-5", "title": "막지 마라", "element": "패러독스", "max": 2, "record": 2},
	{"id": "level_2_1", "code": "2-1", "title": "엘리베이터", "element": "이동 발판", "max": 2, "record": 1},
	{"id": "level_2_2", "code": "2-2", "title": "탑 쌓기", "element": "고스트 위 고스트", "max": 2, "record": 2},
	{"id": "level_2_3", "code": "2-3", "title": "방패", "element": "레이저", "max": 2, "record": 1},
	{"id": "level_2_4", "code": "2-4", "title": "교대 근무", "element": "압력판 이어 받기", "max": 3, "record": 3},
	{"id": "level_2_5", "code": "2-5", "title": "파랑과 주황", "element": "색 문", "max": 3, "record": 2},
	{"id": "level_3_1", "code": "3-1", "title": "릴레이", "element": "시한 버튼", "max": 3, "record": 3},
	{"id": "level_3_2", "code": "3-2", "title": "6초", "element": "짧은 루프", "max": 3, "record": 3},
	{"id": "level_3_3", "code": "3-3", "title": "짐꾼", "element": "상자", "max": 3, "record": 1},
	{"id": "level_3_4", "code": "3-4", "title": "역순", "element": "녹화 순서", "max": 4, "record": 2},
	{"id": "level_3_5", "code": "3-5", "title": "에코", "element": "종합", "max": 4, "record": 3},
]


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return -1


static func find(id: String) -> Dictionary:
	var i: int = index_of(id)
	return LIST[i] if i >= 0 else {}


static func path(id: String) -> String:
	return "res://levels/%s.tscn" % id


## 챕터 번호(0부터).
static func chapter_of(id: String) -> int:
	return maxi(index_of(id), 0) / 5


## 다음 스테이지 id. 마지막이면 "".
static func next_of(id: String) -> String:
	var i: int = index_of(id)
	return LIST[i + 1]["id"] if i >= 0 and i + 1 < LIST.size() else ""


## 별점: ★1 클리어, ★2 상한보다 적은 고스트, ★3 개발자 기록 이하(그러면 ★2 조건도 채운 것으로 친다).
static func stars_for(ghosts: int, max_ghosts: int, record: int) -> int:
	if ghosts < 0:
		return 0
	if ghosts <= record:
		return 3
	return 2 if ghosts < max_ghosts else 1
