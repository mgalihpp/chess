class_name ChessBoard
extends Node2D

signal piece_selected(pos: Vector2i)
signal move_made(move: Dictionary)
signal board_changed

const SQ: int = 64
const LIGHT := Color("#ebecd9")
const DARK := Color("#739552")

var board: Array = []
var en_passant := Vector2i(-1, -1)
var castling: Dictionary = {"wk": true, "wq": true, "bk": true, "bq": true}
var selected := Vector2i(-1, -1)
var legal_targets: Array[Vector2i] = []
var current_turn: int = 0
var last_move: Dictionary = {}
var check_square := Vector2i(-1, -1)
var pieces_root: Node2D
var input_enabled := true

func _ready() -> void:
	pieces_root = Node2D.new()
	pieces_root.name = "Pieces"
	add_child(pieces_root)
	reset()

func reset() -> void:
	board = BoardState.initial_board()
	en_passant = Vector2i(-1, -1)
	castling = {"wk": true, "wq": true, "bk": true, "bq": true}
	selected = Vector2i(-1, -1)
	legal_targets = []
	current_turn = BoardState.PieceColor.WHITE
	last_move = {}
	check_square = Vector2i(-1, -1)
	refresh_pieces()
	queue_redraw()
	board_changed.emit()

func pos_to_square(local: Vector2) -> Vector2i:
	return Vector2i(int(floor(local.x / SQ)), int(floor(local.y / SQ)))

func square_center(sq: Vector2i) -> Vector2:
	return Vector2(sq.x * SQ + SQ * 0.5, sq.y * SQ + SQ * 0.5)

func get_piece(sq: Vector2i) -> Dictionary:
	return BoardState.get_piece(board, sq)

func select(sq: Vector2i) -> void:
	selected = sq
	legal_targets = BoardState.legal_moves(board, sq, en_passant, castling)
	piece_selected.emit(sq)
	queue_redraw()

func deselect() -> void:
	selected = Vector2i(-1, -1)
	legal_targets = []
	queue_redraw()

func refresh_pieces() -> void:
	if pieces_root == null:
		return
	for ch in pieces_root.get_children():
		ch.queue_free()
	for y in 8:
		for x in 8:
			var cell: Dictionary = board[y][x]
			if cell.is_empty():
				continue
			var pc := ChessPiece.new()
			pc.position = Vector2(x * SQ, y * SQ)
			pieces_root.add_child(pc)
			pc.setup(int(cell["type"]), int(cell["color"]))

func compute_en_passant_after(piece: Dictionary, f: Vector2i, tt: Vector2i) -> Vector2i:
	if int(piece["type"]) == BoardState.PieceType.PAWN and abs(tt.y - f.y) == 2:
		return Vector2i(f.x, (f.y + tt.y) >> 1)
	return Vector2i(-1, -1)

func try_move(f: Vector2i, tt: Vector2i, promotion: int = -1) -> Dictionary:
	var piece: Dictionary = BoardState.get_piece(board, f)
	if piece.is_empty():
		return {"ok": false}
	var legal: Array[Vector2i] = BoardState.legal_moves(board, f, en_passant, castling)
	if not legal.has(tt):
		return {"ok": false}
	var mv := {"from": f, "to": tt, "promotion": promotion}
	var target: Dictionary = BoardState.get_piece(board, tt)
	var captured_preview: Dictionary = {}
	if not target.is_empty():
		captured_preview = target.duplicate()
	elif int(piece["type"]) == BoardState.PieceType.PAWN and tt == en_passant:
		captured_preview = BoardState.get_piece(board, Vector2i(tt.x, f.y)).duplicate()
	var piece_copy: Dictionary = piece.duplicate()
	var new_ep := compute_en_passant_after(piece, f, tt)
	BoardState.update_castling_on_move(castling, mv, piece, captured_preview)
	var rec: Dictionary = BoardState.apply(board, mv, en_passant)
	en_passant = new_ep
	last_move = {"from": f, "to": tt}
	deselect()
	refresh_pieces()
	check_square = Vector2i(-1, -1)
	if BoardState.in_check(board, 1 - int(piece_copy["color"]), en_passant):
		check_square = BoardState.find_king(board, 1 - int(piece_copy["color"]))
	elif BoardState.in_check(board, int(piece_copy["color"]), en_passant):
		check_square = BoardState.find_king(board, int(piece_copy["color"]))
	queue_redraw()
	board_changed.emit()
	return {"ok": true, "record": rec, "captured": captured_preview, "piece": piece_copy, "new_en_passant": new_ep}

func restore_en_passant(v: Vector2i) -> void:
	en_passant = v
	refresh_pieces()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var sq := pos_to_square(get_local_mouse_position())
			if not BoardState.inside(sq):
				return
			get_viewport().set_input_as_handled()
			if selected == Vector2i(-1, -1):
				var pc: Dictionary = BoardState.get_piece(board, sq)
				if not pc.is_empty() and int(pc["color"]) == current_turn:
					select(sq)
				return
			if sq == selected:
				deselect()
				return
			if legal_targets.has(sq):
				var promo := -1
				var moving: Dictionary = BoardState.get_piece(board, selected)
				if not moving.is_empty() and int(moving["type"]) == BoardState.PieceType.PAWN and (sq.y == 0 or sq.y == 7):
					promo = BoardState.PieceType.QUEEN
				move_made.emit({"from": selected, "to": sq, "promotion": promo})
				return
			var pc2: Dictionary = BoardState.get_piece(board, sq)
			if not pc2.is_empty() and int(pc2["color"]) == current_turn:
				select(sq)
			else:
				deselect()

func _draw() -> void:
	for y in 8:
		for x in 8:
			var sq := Vector2i(x, y)
			var base := LIGHT if (x + y) % 2 == 0 else DARK
			if last_move.has("from") and (sq == last_move["from"] or sq == last_move["to"]):
				base = base.lerp(Color("#f7ec59"), 0.45)
			if sq == selected:
				base = base.lerp(Color("#ffd54a"), 0.6)
			if sq == check_square:
				base = base.lerp(Color("#e4572e"), 0.65)
			draw_rect(Rect2(x * SQ, y * SQ, SQ, SQ), base)
	for t in legal_targets:
		var c := square_center(t)
		var occupied: Dictionary = BoardState.get_piece(board, t)
		if occupied.is_empty() and t != en_passant:
			draw_circle(c, 10.0, Color(0.1, 0.35, 0.1, 0.55))
		else:
			draw_arc(c, 26.0, 0.0, TAU, 32, Color(0.7, 0.15, 0.1, 0.9), 4.0)
