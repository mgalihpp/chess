extends Node2D

const DIFF_NAMES: Array[String] = ["Mudah", "Sedang", "Susah"]
const COLOR_NAMES: Array[String] = ["Putih", "Hitam"]

var board: ChessBoard
var manager: GameManager
var turn_label: Label
var status_label: Label
var _diff_buttons: Array[Button] = []
var _color_buttons: Array[Button] = []
var _menu: Control
var _ai_busy := false
var _ai_gen := 0

func _ready() -> void:
	board = ChessBoard.new()
	board.name = "Board"
	board.position = Vector2(16, 16)
	add_child(board)
	manager = GameManager.new()
	manager.name = "GameManager"
	add_child(manager)
	manager.bind(board)
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(544, 16)
	panel.custom_minimum_size = Vector2(220, 0)
	panel.add_theme_constant_override("separation", 10)
	layer.add_child(panel)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(turn_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)
	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(_on_restart)
	panel.add_child(restart_btn)
	var undo_btn := Button.new()
	undo_btn.text = "Undo"
	undo_btn.pressed.connect(_on_undo)
	panel.add_child(undo_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Menu Utama"
	menu_btn.pressed.connect(_on_menu)
	panel.add_child(menu_btn)
	board.board_changed.connect(_on_board_changed)
	manager.turn_changed.connect(_on_turn)
	manager.status_changed.connect(_on_status)
	_build_menu(layer)
	_show_menu()
	_on_turn(manager.current_turn)
	_on_status(manager.status_text)

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	return l

func _build_menu(layer: CanvasLayer) -> void:
	_menu = Control.new()
	_menu.name = "MenuOverlay"
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.05, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Catur 2D"
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Pilih kesulitan dan warna, lalu mulai."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_section("Tingkat kesulitan:"))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(drow)
	var dgroup := ButtonGroup.new()
	for i in DIFF_NAMES.size():
		var b := Button.new()
		b.text = DIFF_NAMES[i]
		b.toggle_mode = true
		b.button_group = dgroup
		b.custom_minimum_size = Vector2(118, 44)
		drow.add_child(b)
		_diff_buttons.append(b)
	_diff_buttons[1].button_pressed = true
	box.add_child(_section("Main sebagai:"))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(crow)
	var cgroup := ButtonGroup.new()
	for i in COLOR_NAMES.size():
		var b2 := Button.new()
		b2.text = COLOR_NAMES[i]
		b2.toggle_mode = true
		b2.button_group = cgroup
		b2.custom_minimum_size = Vector2(150, 44)
		crow.add_child(b2)
		_color_buttons.append(b2)
	_color_buttons[0].button_pressed = true
	var start := Button.new()
	start.text = "Mulai Permainan"
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(_start_game)
	box.add_child(start)

func _show_menu() -> void:
	_ai_gen += 1
	_ai_busy = false
	board.input_enabled = false
	_menu.visible = true

func _start_game() -> void:
	var diff := 1
	for i in _diff_buttons.size():
		if _diff_buttons[i].button_pressed:
			diff = i
	var color := 0
	for i in _color_buttons.size():
		if _color_buttons[i].button_pressed:
			color = i
	_ai_gen += 1
	_ai_busy = false
	manager.setup_match(true, color, diff)
	_menu.visible = false
	_on_board_changed()

func _on_board_changed() -> void:
	var playing := not manager.game_over
	board.input_enabled = playing and manager.is_human_turn() and not _ai_busy and not _menu.visible

func _ai_move() -> void:
	if _ai_busy or not manager.vs_ai or manager.is_human_turn() or manager.game_over:
		return
	if manager.ai == null:
		return
	_ai_busy = true
	var gen := _ai_gen
	board.input_enabled = false
	status_label.text = "AI berpikir..."
	await get_tree().create_timer(0.35).timeout
	if gen != _ai_gen or manager.game_over or manager.is_human_turn():
		_ai_busy = false
		return
	var mv: Dictionary = manager.ai.choose_move(board.board, board.en_passant, board.castling, manager.halfmove, manager.current_turn, manager.ai_difficulty)
	_ai_busy = false
	if gen != _ai_gen or mv.is_empty():
		return
	manager.request_move(mv["from"], mv["to"], int(mv.get("promotion", -1)), true)

func _on_turn(color: int) -> void:
	if turn_label == null:
		return
	var who := "Giliran: Putih" if color == BoardState.PieceColor.WHITE else "Giliran: Hitam"
	if manager != null and manager.vs_ai:
		who += " (Kamu)" if color == manager.human_color else " (AI)"
	turn_label.text = who
	if manager.vs_ai and not manager.game_over and not manager.is_human_turn() and not _ai_busy:
		_ai_move()
	board.input_enabled = not manager.game_over and manager.is_human_turn() and not _ai_busy and not _menu.visible

func _on_status(text: String) -> void:
	if status_label == null:
		return
	status_label.text = text

func _on_restart() -> void:
	_ai_gen += 1
	_ai_busy = false
	manager.restart()

func _on_undo() -> void:
	if _ai_busy:
		return
	_ai_gen += 1
	manager.undo_round()
	_on_board_changed()

func _on_menu() -> void:
	_show_menu()
