extends "res://tests/test_base.gd"
## 첫 플레이 안내(D1): 1-1~1-3만, 고스트가 생기면 다음 문구, 깬 스테이지는 다시 안 띄움, 터치면 "시간 바",
## 입력 없는 시간 초과 2번 연속이면 한 번, 릴스 모드에선 숨김.


func test_level() -> String:
	return "res://levels/level_1_1.tscn"


func run_case() -> void:
	var hints: Hints = hud.hints
	await restart()
	await frame()
	await frame()
	check("1-1: first hint tells R ends the loop", hints.visible and hints.text.begins_with("R로 루프를 끝내면"), hints.text)
	TouchControls.force_enabled = true
	await frame()
	check("1-1 on touch: hint says hold the timer bar", hints.text.begins_with("시간 바를 길게 눌러"), hints.text)
	TouchControls.force_enabled = false
	await run_loop(func(t: int) -> void: steer_to(176.0), 40)
	await frame()
	check("1-1 after the first ghost: step on your past self", hints.text == "과거의 나를 밟고 올라가 보세요", hints.text)
	(main.get_node("ReelsMode") as ReelsMode).set_active(true)
	await frame()
	check("reels mode hides the hint (HUD hidden)", not hints.is_visible_in_tree())
	(main.get_node("ReelsMode") as ReelsMode).set_active(false)
	Progress.record_clear("level_1_1", 1)
	await frame()
	check("cleared stage never shows its hint again (saved progress)", not hints.visible)

	# 힌트 없는 스테이지, 아무 입력 없이 시간 초과 2번 → 한 번만 안내
	main.load_level(load("res://levels/level_2_1.tscn"))
	level = main.level
	await frame()
	check("no stage hint outside 1-1~1-3", not hints.visible)
	await run_loop()
	await frame()
	var after_one: bool = hints.visible
	await run_loop()
	await frame()
	check("two idle timeouts in a row -> 'R ends the loop any time' once", not after_one and hints.visible and hints.text == "R을 누르면 언제든 루프를 끝낼 수 있어요" and Progress.has_flag(Hints.IDLE_FLAG), hints.text)
	await run_loop()
	await frame()
	var hidden_next: bool = not hints.visible
	await run_loop()
	await run_loop()
	await frame()
	check("idle hint disappears after that loop and never comes back", hidden_next and not hints.visible)
