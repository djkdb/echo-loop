extends "res://tests/test_base.gd"
## 보통 화면: 방이 y 300~1030 안에 레벨 줌으로. 릴스 모드(F9): HUD 숨김, 방이 y 300~1030·오른쪽 띠 밖에 꽉 차게,
## 릴스 텍스트(y 240~300), 다시 F9로 원래대로.


func test_level() -> String:
	return "res://levels/level_1_2.tscn"


func run_case() -> void:
	var reels: ReelsMode = main.get_node("ReelsMode")
	# 루프 시작 화면 흔들림(0.3초)이 끝난 뒤에 잰다
	await tick(30)
	var normal: Rect2 = reels.room_screen_rect()
	var area: Rect2 = RoomCamera.NORMAL_TARGET
	check("normal view: room inside y 300~1030 at the level's zoom (2.0 = 640px wide)", area.grow(0.5).encloses(normal) and absf(normal.size.x - 640.0) < 1.0, str(normal))
	await tap_key(KEY_F9)
	await frame()
	await frame()
	var r: Rect2 = reels.room_screen_rect()
	var target: Rect2 = ReelsMode.ROOM_TARGET
	check("F9: reels mode on, HUD hidden", reels.active and not hud.visible)
	check("room fits inside y 300~1030 and avoids the right strip", target.grow(0.5).encloses(r), "room on screen=%s target=%s" % [r, target])
	check("room fills the target on one axis", absf(r.size.x - target.size.x) < 1.0 or absf(r.size.y - target.size.y) < 1.0, str(r.size))
	check("top text slot shows the loop line", (reels._label as Label).text == "10초 전의 나 × 1" and (reels._layer as CanvasLayer).visible, (reels._label as Label).text)
	await tap_key(KEY_F9)
	await frame()
	await frame()
	check("F9 again: back to normal view and HUD", not reels.active and hud.visible and reels.room_screen_rect().is_equal_approx(normal), "%s vs %s" % [reels.room_screen_rect(), normal])
	check("game keeps running in reels mode (loop timer advanced)", lm.tick > 0)
