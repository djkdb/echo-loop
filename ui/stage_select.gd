class_name StageSelect
extends Control
## 스테이지 선택 화면: 챕터 3개 × 5스테이지 카드, 별점 합계, 고른 스테이지 정보.
## 방향키(ui_*)로 고르고 Enter/E로 시작, 카드를 클릭·탭해도 시작. Esc는 타이틀로.
## 시작하면 Progress.pending_stage에 남기고 게임 씬(main.tscn)으로 바꾼다.

const GAME_SCENE: String = "res://game/main.tscn"
const TITLE_SCENE: String = "res://ui/title.tscn"
const CARD_SIZE: Vector2 = Vector2(124, 150)
const CARD_GAP: float = 14.0

var cards: Array[StageCard] = []

var _font: Font = preload("res://assets/fonts/hud_font.tres")
var _info_title: Label
var _info_element: Label
var _info_record: Label
var _total: StarIcons
var _total_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_add_label("STAGES", Rect2(0, 60, 720, 90), 72, Palette.ME)
	_total = StarIcons.new()
	_total.total = 1
	_total.count = 1
	_total.star_size = 16.0
	_total.position = Vector2(250, 160)
	_total.size = Vector2(40, 40)
	add_child(_total)
	_total_label = _add_label("", Rect2(290, 158, 200, 44), 32, Palette.SIGNAL)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var x0: float = (720.0 - (5.0 * CARD_SIZE.x + 4.0 * CARD_GAP)) * 0.5
	for c in 3:
		var y0: float = 250.0 + c * 255.0
		var head: Label = _add_label("CHAPTER %d   %s" % [c + 1, Stages.CHAPTER_NAMES[c]], Rect2(x0, y0, 680, 44), 30, Palette.SUB_TEXT)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		for k in 5:
			var s: Dictionary = Stages.LIST[c * 5 + k]
			var card := StageCard.new()
			card.stage_id = s["id"]
			card.code = s["code"]
			card.position = Vector2(x0 + k * (CARD_SIZE.x + CARD_GAP), y0 + 52.0)
			card.size = CARD_SIZE
			card.chosen.connect(start_stage)
			card.focused.connect(_show_info)
			add_child(card)
			cards.append(card)
	_info_title = _add_label("", Rect2(0, 1040, 720, 64), 44, Palette.ME)
	_info_element = _add_label("", Rect2(0, 1104, 720, 40), 28, Palette.SUB_TEXT)
	_info_record = _add_label("", Rect2(0, 1146, 720, 40), 26, Palette.EXIT)
	_add_label("방향키 선택 · Enter/E 시작 · Esc 타이틀", Rect2(0, 1214, 720, 36), 22, Color(Palette.SUB_TEXT, 0.7))
	refresh()
	_focus_default()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if ResourceLoader.exists(TITLE_SCENE):
			get_tree().change_scene_to_file(TITLE_SCENE)


## 기록을 다시 읽어 카드·합계를 그린다.
func refresh() -> void:
	for card: StageCard in cards:
		card.unlocked = Progress.is_unlocked(card.stage_id)
		card.cleared = Progress.is_cleared(card.stage_id)
		card.stars = Progress.stars(card.stage_id)
		card.queue_redraw()
	_total_label.text = "%d / %d" % [Progress.total_stars(), Stages.LIST.size() * 3]


func start_stage(stage_id: String) -> void:
	if not Progress.is_unlocked(stage_id):
		return
	Progress.pending_stage = stage_id
	get_tree().change_scene_to_file(GAME_SCENE)


func _focus_default() -> void:
	# 마지막으로 한 스테이지, 없으면 아직 못 깬 첫 스테이지에 포커스
	var target: String = Progress.pending_stage
	if target == "" or Stages.index_of(target) < 0:
		for s: Dictionary in Stages.LIST:
			if Progress.is_unlocked(s["id"]) and not Progress.is_cleared(s["id"]):
				target = s["id"]
				break
	var i: int = maxi(Stages.index_of(target), 0)
	cards[i].grab_focus()
	_show_info(cards[i].stage_id)


func _show_info(stage_id: String) -> void:
	var s: Dictionary = Stages.find(stage_id)
	_info_title.text = "%s  %s" % [s["code"], s["title"]] if Progress.is_unlocked(stage_id) else "%s  ???" % s["code"]
	_info_element.text = "새 요소: %s · 고스트 상한 %d명" % [s["element"], s["max"]]
	var mine: String = "내 기록 %d명" % Progress.best_ghosts(stage_id) if Progress.is_cleared(stage_id) else "아직 못 깸"
	_info_record.text = "%s · ★3 기준 %d명 이하" % [mine, s["record"]]


func _add_label(text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
