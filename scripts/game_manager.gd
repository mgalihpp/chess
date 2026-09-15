class_name GameManager
extends Node

signal turn_changed(color: int)
signal game_ended(result: String)
signal status_changed(text: String)

enum GameState { PLAYING, CHECK, CHECKMATE, STALEMATE, DRAW }

var board: ChessBoard
var current_turn: int = 0
var history: Array = []
var halfmove: int = 0
var fullmove: int = 1
var status: int = 0
var status_text: String = ""
var game_over: bool = false
var vs_ai := false
var human_color: int = 0
var ai_color: int = 1
var ai_difficulty: int = 1
var ai: ChessAI = null

func bind(b: ChessBoard) -> void:
	board = b
	current_turn = BoardState.PieceColor.WHITE
	board.current_turn = current_turn
	if not board.move_made.is_connected(_on_move_made):
		board.move_made.connect(_on_move_made)
	_update_status()

func setup_match(p_vs_ai: bool, p_human_color: int, p_difficulty: int) -> void:
	vs_ai = p_vs_ai
	human_color = p_human_color
	ai_color = 1 - p_human_color
	ai_difficulty = p_difficulty
	ai = ChessAI.new() if p_vs_ai else null
	restart()

func is_human_turn() -> bool:
	return (not vs_ai) or current_turn == human_color

func _on_move_made(move: Dictionary) -> void:
	request_move(move["from"], move["to"], int(move.get("promotion", -1)))

func request_move(f: Vector2i, tt: Vector2i, promotion: int = -1, by_ai: bool = false) -> bool:
	if game_over or board == null:
		return false
	if vs_ai and not by_ai and current_turn != human_color:
		return false
	var piece: Dictionary = BoardState.get_piece(board.board, f)
	if piece.is_empty() or int(piece["color"]) != current_turn:
		return false
	var legal: Array[Vector2i] = BoardState.legal_moves(board.board, f, board.en_passant, board.castling)
	if not legal.has(tt):
		return false
	if int(piece["type"]) == BoardState.PieceType.PAWN and (tt.y == 0 or tt.y == 7) and promotion == -1:
		promotion = BoardState.PieceType.QUEEN
	var prev_ep: Vector2i = board.en_passant
	var prev_castling: Dictionary = board.castling.duplicate()
	var prev_half: int = halfmove
	var prev_full: int = fullmove
	var prev_turn: int = current_turn
	var res: Dictionary = board.try_move(f, tt, promotion)
	if not bool(res.get("ok", false)):
		return false
	var moved: Dictionary = res["piece"]
	var captured: Dictionary = res["captured"]
	if int(moved["type"]) == BoardState.PieceType.PAWN or not captured.is_empty():
		halfmove = 0
	else:
		halfmove += 1
	if current_turn == BoardState.PieceColor.BLACK:
		fullmove += 1
	current_turn = 1 - current_turn
	board.current_turn = current_turn
	history.append({"record": res["record"], "prev_en_passant": prev_ep, "prev_castling": prev_castling, "prev_halfmove": prev_half, "prev_fullmove": prev_full, "prev_turn": prev_turn})
	_update_status()
	return true

func undo_round() -> bool:
	if history.is_empty():
		return false
	undo()
	while vs_ai and current_turn == ai_color and not history.is_empty():
		undo()
	return true

func undo() -> bool:
	if history.is_empty() or board == null:
		return false
	var h: Dictionary = history.pop_back()
	BoardState.undo(board.board, h["record"])
	board.en_passant = h["prev_en_passant"]
	board.castling = (h["prev_castling"] as Dictionary).duplicate()
	halfmove = int(h["prev_halfmove"])
	fullmove = int(h["prev_fullmove"])
	current_turn = int(h["prev_turn"])
	board.current_turn = current_turn
	game_over = false
	board.last_move = {}
	if not history.is_empty():
		var last_rec: Dictionary = history[history.size() - 1]["record"]
		var lm: Dictionary = last_rec["move"]
		board.last_move = {"from": lm["from"], "to": lm["to"]}
	board.deselect()
	board.refresh_pieces()
	_update_status()
	return true

func restart() -> void:
	history.clear()
	halfmove = 0
	fullmove = 1
	current_turn = BoardState.PieceColor.WHITE
	game_over = false
	if board != null:
		board.current_turn = current_turn
		board.reset()
	_update_status()

func legal_count(color: int) -> int:
	if board == null:
		return 0
	var all: Dictionary = BoardState.all_legal(board.board, color, board.en_passant, board.castling)
	var n := 0
	for k in all:
		n += (all[k] as Array).size()
	return n

func _update_status() -> void:
	if board == null:
		return
	var foe: int = current_turn
	var in_chk: bool = BoardState.in_check(board.board, foe, board.en_passant)
	var moves: Dictionary = BoardState.all_legal(board.board, foe, board.en_passant, board.castling)
	var has_moves: bool = not moves.is_empty()
	var who := "Putih" if foe == BoardState.PieceColor.WHITE else "Hitam"
	if not has_moves and in_chk:
		status = GameState.CHECKMATE
		var winner := "Hitam" if foe == BoardState.PieceColor.WHITE else "Putih"
		status_text = "Skakmat. %s menang." % winner
		game_over = true
		board.check_square = BoardState.find_king(board.board, foe)
	elif not has_moves:
		status = GameState.STALEMATE
		status_text = "Stalemate. Draw."
		game_over = true
	elif BoardState.insufficient_material(board.board):
		status = GameState.DRAW
		status_text = "Draw. Material tidak cukup."
		game_over = true
	elif halfmove >= 100:
		status = GameState.DRAW
		status_text = "Draw. Aturan 50 langkah."
		game_over = true
	elif in_chk:
		status = GameState.CHECK
		status_text = "Skak. Giliran %s." % who
		board.check_square = BoardState.find_king(board.board, foe)
	else:
		status = GameState.PLAYING
		status_text = "Giliran %s." % who
		board.check_square = Vector2i(-1, -1)
	board.queue_redraw()
	turn_changed.emit(current_turn)
	status_changed.emit(status_text)
	if game_over:
		game_ended.emit(status_text)
