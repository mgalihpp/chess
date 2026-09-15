class_name BoardState
extends RefCounted

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

const KNIGHT_STEPS: Array = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
const KING_STEPS: Array = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const BISHOP_DIRS: Array = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const ROOK_DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const QUEEN_DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < 8 and p.y >= 0 and p.y < 8

static func get_piece(board: Array, p: Vector2i) -> Dictionary:
	if not inside(p):
		return {}
	return board[p.y][p.x]

static func initial_board() -> Array:
	var board: Array = []
	for y in 8:
		var row: Array = []
		for x in 8:
			row.append({})
		board.append(row)
	var back: Array = [PieceType.ROOK, PieceType.KNIGHT, PieceType.BISHOP, PieceType.QUEEN, PieceType.KING, PieceType.BISHOP, PieceType.KNIGHT, PieceType.ROOK]
	for x in 8:
		board[0][x] = {"type": back[x], "color": PieceColor.BLACK, "has_moved": false}
		board[1][x] = {"type": PieceType.PAWN, "color": PieceColor.BLACK, "has_moved": false}
		board[6][x] = {"type": PieceType.PAWN, "color": PieceColor.WHITE, "has_moved": false}
		board[7][x] = {"type": back[x], "color": PieceColor.WHITE, "has_moved": false}
	return board

static func pseudo_moves(board: Array, p: Vector2i, en_passant: Vector2i, out_moves: Array) -> void:
	var piece: Dictionary = get_piece(board, p)
	if piece.is_empty():
		return
	var t: int = int(piece["type"])
	var c: int = int(piece["color"])
	if t == PieceType.PAWN:
		var dir: int = -1 if c == PieceColor.WHITE else 1
		var start: int = 6 if c == PieceColor.WHITE else 1
		var one := Vector2i(p.x, p.y + dir)
		if inside(one) and get_piece(board, one).is_empty():
			out_moves.append(one)
			var two := Vector2i(p.x, p.y + dir * 2)
			if p.y == start and inside(two) and get_piece(board, two).is_empty():
				out_moves.append(two)
		for dx in [-1, 1]:
			var q := Vector2i(p.x + dx, p.y + dir)
			if not inside(q):
				continue
			var tp: Dictionary = get_piece(board, q)
			if not tp.is_empty() and int(tp["color"]) != c:
				out_moves.append(q)
			elif q == en_passant:
				out_moves.append(q)
	elif t == PieceType.KNIGHT:
		for o in KNIGHT_STEPS:
			var q2: Vector2i = p + o
			if not inside(q2):
				continue
			var kp: Dictionary = get_piece(board, q2)
			if kp.is_empty() or int(kp["color"]) != c:
				out_moves.append(q2)
	elif t == PieceType.BISHOP or t == PieceType.ROOK or t == PieceType.QUEEN:
		var dirs: Array = QUEEN_DIRS
		if t == PieceType.BISHOP:
			dirs = BISHOP_DIRS
		elif t == PieceType.ROOK:
			dirs = ROOK_DIRS
		for d in dirs:
			var r: Vector2i = p + d
			while inside(r):
				var sp: Dictionary = get_piece(board, r)
				if sp.is_empty():
					out_moves.append(r)
				else:
					if int(sp["color"]) != c:
						out_moves.append(r)
					break
				r += d
	else:
		for o2 in KING_STEPS:
			var q3: Vector2i = p + o2
			if not inside(q3):
				continue
			var ep: Dictionary = get_piece(board, q3)
			if ep.is_empty() or int(ep["color"]) != c:
				out_moves.append(q3)

static func attacked(board: Array, sq: Vector2i, by_color: int, _ep: Vector2i) -> bool:
	if not inside(sq):
		return false
	var pdir: int = -1 if by_color == PieceColor.WHITE else 1
	for dx in [-1, 1]:
		var pp := Vector2i(sq.x - dx, sq.y - pdir)
		if inside(pp):
			var tp: Dictionary = get_piece(board, pp)
			if not tp.is_empty() and int(tp["type"]) == PieceType.PAWN and int(tp["color"]) == by_color:
				return true
	for o in KNIGHT_STEPS:
		var q: Vector2i = sq + o
		if inside(q):
			var kp: Dictionary = get_piece(board, q)
			if not kp.is_empty() and int(kp["type"]) == PieceType.KNIGHT and int(kp["color"]) == by_color:
				return true
	for o2 in KING_STEPS:
		var q2: Vector2i = sq + o2
		if inside(q2):
			var kg: Dictionary = get_piece(board, q2)
			if not kg.is_empty() and int(kg["type"]) == PieceType.KING and int(kg["color"]) == by_color:
				return true
	for d in BISHOP_DIRS:
		var r: Vector2i = sq + d
		while inside(r):
			var sp: Dictionary = get_piece(board, r)
			if not sp.is_empty():
				if int(sp["color"]) == by_color and (int(sp["type"]) == PieceType.BISHOP or int(sp["type"]) == PieceType.QUEEN):
					return true
				break
			r += d
	for d2 in ROOK_DIRS:
		var r2: Vector2i = sq + d2
		while inside(r2):
			var sp2: Dictionary = get_piece(board, r2)
			if not sp2.is_empty():
				if int(sp2["color"]) == by_color and (int(sp2["type"]) == PieceType.ROOK or int(sp2["type"]) == PieceType.QUEEN):
					return true
				break
			r2 += d2
	return false

static func find_king(board: Array, color: int) -> Vector2i:
	for y in 8:
		for x in 8:
			var cell: Dictionary = board[y][x]
			if not cell.is_empty() and int(cell["type"]) == PieceType.KING and int(cell["color"]) == color:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

static func in_check(board: Array, color: int, en_passant: Vector2i) -> bool:
	var k := find_king(board, color)
	if k == Vector2i(-1, -1):
		return false
	return attacked(board, k, 1 - color, en_passant)

static func apply(board: Array, move: Dictionary, en_passant: Vector2i) -> Dictionary:
	var f: Vector2i = move["from"]
	var tt: Vector2i = move["to"]
	var promo_in: int = int(move.get("promotion", -1))
	var piece: Dictionary = board[f.y][f.x]
	var prev_has: bool = bool(piece["has_moved"])
	var captured: Dictionary = {}
	var cap_pos := Vector2i(-1, -1)
	var was_ep := false
	var target: Dictionary = board[tt.y][tt.x]
	if int(piece["type"]) == PieceType.PAWN and tt == en_passant and target.is_empty():
		cap_pos = Vector2i(tt.x, f.y)
		captured = (board[cap_pos.y][cap_pos.x] as Dictionary).duplicate()
		board[cap_pos.y][cap_pos.x] = {}
		was_ep = true
	else:
		if not target.is_empty():
			captured = (target as Dictionary).duplicate()
			cap_pos = tt
	board[f.y][f.x] = {}
	var promo_applied: int = -1
	if int(piece["type"]) == PieceType.PAWN and (tt.y == 0 or tt.y == 7):
		if promo_in == PieceType.KNIGHT or promo_in == PieceType.BISHOP or promo_in == PieceType.ROOK or promo_in == PieceType.QUEEN:
			promo_applied = promo_in
		else:
			promo_applied = PieceType.QUEEN
		piece["type"] = promo_applied
	piece["has_moved"] = true
	board[tt.y][tt.x] = piece
	var was_castle := false
	var rook_from := Vector2i(-1, -1)
	var rook_to := Vector2i(-1, -1)
	var rook_prev := false
	if int(piece["type"]) == PieceType.KING and abs(tt.x - f.x) == 2:
		was_castle = true
		if tt.x == 6:
			rook_from = Vector2i(7, f.y)
			rook_to = Vector2i(5, f.y)
		else:
			rook_from = Vector2i(0, f.y)
			rook_to = Vector2i(3, f.y)
		var rook: Dictionary = board[rook_from.y][rook_from.x]
		rook_prev = bool(rook["has_moved"])
		board[rook_from.y][rook_from.x] = {}
		rook["has_moved"] = true
		board[rook_to.y][rook_to.x] = rook
	return {"move": {"from": f, "to": tt, "promotion": promo_in}, "captured": captured, "cap_pos": cap_pos, "prev_has_moved": prev_has, "prev_en_passant": en_passant, "promotion": promo_applied, "was_castle": was_castle, "rook_from": rook_from, "rook_to": rook_to, "rook_prev_has_moved": rook_prev, "was_en_passant": was_ep}

static func undo(board: Array, record: Dictionary) -> void:
	var mv: Dictionary = record["move"]
	var f: Vector2i = mv["from"]
	var tt: Vector2i = mv["to"]
	var piece: Dictionary = board[tt.y][tt.x]
	if int(record["promotion"]) != -1:
		piece["type"] = PieceType.PAWN
	piece["has_moved"] = bool(record["prev_has_moved"])
	board[tt.y][tt.x] = {}
	board[f.y][f.x] = piece
	if bool(record.get("was_castle", false)):
		var rf: Vector2i = record["rook_from"]
		var rt: Vector2i = record["rook_to"]
		var rook: Dictionary = board[rt.y][rt.x]
		rook["has_moved"] = bool(record["rook_prev_has_moved"])
		board[rt.y][rt.x] = {}
		board[rf.y][rf.x] = rook
	var captured: Dictionary = record["captured"]
	var cap_pos: Vector2i = record["cap_pos"]
	if not captured.is_empty() and inside(cap_pos):
		board[cap_pos.y][cap_pos.x] = captured

static func legal_moves(board: Array, p: Vector2i, en_passant: Vector2i, castling: Dictionary) -> Array[Vector2i]:
	var filtered: Array[Vector2i] = []
	var piece: Dictionary = get_piece(board, p)
	if piece.is_empty():
		return filtered
	var c: int = int(piece["color"])
	var t: int = int(piece["type"])
	var pseudo: Array = []
	pseudo_moves(board, p, en_passant, pseudo)
	for dest in pseudo:
		var d: Vector2i = dest
		var promo: int = -1
		if t == PieceType.PAWN and (d.y == 0 or d.y == 7):
			promo = PieceType.QUEEN
		var mv := {"from": p, "to": d, "promotion": promo}
		var rec: Dictionary = apply(board, mv, en_passant)
		var bad: bool = in_check(board, c, Vector2i(-1, -1))
		undo(board, rec)
		if not bad:
			filtered.append(d)
	if t == PieceType.KING and not in_check(board, c, en_passant):
		if c == PieceColor.WHITE and p == Vector2i(4, 7):
			if bool(castling.get("wk", false)) and get_piece(board, Vector2i(5, 7)).is_empty() and get_piece(board, Vector2i(6, 7)).is_empty():
				var rk: Dictionary = get_piece(board, Vector2i(7, 7))
				if not rk.is_empty() and int(rk["type"]) == PieceType.ROOK and int(rk["color"]) == PieceColor.WHITE and not bool(rk["has_moved"]):
					if not attacked(board, Vector2i(4, 7), PieceColor.BLACK, en_passant) and not attacked(board, Vector2i(5, 7), PieceColor.BLACK, en_passant) and not attacked(board, Vector2i(6, 7), PieceColor.BLACK, en_passant):
						filtered.append(Vector2i(6, 7))
			if bool(castling.get("wq", false)) and get_piece(board, Vector2i(3, 7)).is_empty() and get_piece(board, Vector2i(2, 7)).is_empty() and get_piece(board, Vector2i(1, 7)).is_empty():
				var rk2: Dictionary = get_piece(board, Vector2i(0, 7))
				if not rk2.is_empty() and int(rk2["type"]) == PieceType.ROOK and int(rk2["color"]) == PieceColor.WHITE and not bool(rk2["has_moved"]):
					if not attacked(board, Vector2i(4, 7), PieceColor.BLACK, en_passant) and not attacked(board, Vector2i(3, 7), PieceColor.BLACK, en_passant) and not attacked(board, Vector2i(2, 7), PieceColor.BLACK, en_passant):
						filtered.append(Vector2i(2, 7))
		elif c == PieceColor.BLACK and p == Vector2i(4, 0):
			if bool(castling.get("bk", false)) and get_piece(board, Vector2i(5, 0)).is_empty() and get_piece(board, Vector2i(6, 0)).is_empty():
				var rb: Dictionary = get_piece(board, Vector2i(7, 0))
				if not rb.is_empty() and int(rb["type"]) == PieceType.ROOK and int(rb["color"]) == PieceColor.BLACK and not bool(rb["has_moved"]):
					if not attacked(board, Vector2i(4, 0), PieceColor.WHITE, en_passant) and not attacked(board, Vector2i(5, 0), PieceColor.WHITE, en_passant) and not attacked(board, Vector2i(6, 0), PieceColor.WHITE, en_passant):
						filtered.append(Vector2i(6, 0))
			if bool(castling.get("bq", false)) and get_piece(board, Vector2i(3, 0)).is_empty() and get_piece(board, Vector2i(2, 0)).is_empty() and get_piece(board, Vector2i(1, 0)).is_empty():
				var rb2: Dictionary = get_piece(board, Vector2i(0, 0))
				if not rb2.is_empty() and int(rb2["type"]) == PieceType.ROOK and int(rb2["color"]) == PieceColor.BLACK and not bool(rb2["has_moved"]):
					if not attacked(board, Vector2i(4, 0), PieceColor.WHITE, en_passant) and not attacked(board, Vector2i(3, 0), PieceColor.WHITE, en_passant) and not attacked(board, Vector2i(2, 0), PieceColor.WHITE, en_passant):
						filtered.append(Vector2i(2, 0))
	return filtered

static func all_legal(board: Array, color: int, en_passant: Vector2i, castling: Dictionary) -> Dictionary:
	var res: Dictionary = {}
	for y in 8:
		for x in 8:
			var pos := Vector2i(x, y)
			var pc: Dictionary = get_piece(board, pos)
			if not pc.is_empty() and int(pc["color"]) == color:
				var mv: Array[Vector2i] = legal_moves(board, pos, en_passant, castling)
				if not mv.is_empty():
					res[pos] = mv
	return res

static func insufficient_material(board: Array) -> bool:
	var minors: int = 0
	for y in 8:
		for x in 8:
			var cell: Dictionary = board[y][x]
			if cell.is_empty():
				continue
			var tt: int = int(cell["type"])
			if tt == PieceType.PAWN or tt == PieceType.ROOK or tt == PieceType.QUEEN:
				return false
			if tt == PieceType.KNIGHT or tt == PieceType.BISHOP:
				minors += 1
	return minors <= 1

static func update_castling_on_move(castling: Dictionary, move: Dictionary, piece: Dictionary, captured: Dictionary) -> void:
	var f: Vector2i = move["from"]
	var tt: Vector2i = move["to"]
	var c: int = int(piece["color"])
	var t: int = int(piece["type"])
	if t == PieceType.KING:
		if c == PieceColor.WHITE:
			castling["wk"] = false
			castling["wq"] = false
		else:
			castling["bk"] = false
			castling["bq"] = false
	elif t == PieceType.ROOK:
		if f == Vector2i(0, 7):
			castling["wq"] = false
		elif f == Vector2i(7, 7):
			castling["wk"] = false
		elif f == Vector2i(0, 0):
			castling["bq"] = false
		elif f == Vector2i(7, 0):
			castling["bk"] = false
	if not captured.is_empty() and int(captured["type"]) == PieceType.ROOK:
		if tt == Vector2i(0, 7):
			castling["wq"] = false
		elif tt == Vector2i(7, 7):
			castling["wk"] = false
		elif tt == Vector2i(0, 0):
			castling["bq"] = false
		elif tt == Vector2i(7, 0):
			castling["bk"] = false

static func alg(p: Vector2i) -> String:
	return String.chr(97 + p.x) + str(8 - p.y)
