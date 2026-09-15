class_name ChessAI
extends RefCounted

enum Difficulty { EASY, MEDIUM, HARD }

const VAL := {0: 100, 1: 320, 2: 330, 3: 500, 4: 900, 5: 0}
const MATE := 100000
const INF := 2000000
const MAX_DEPTH := 3
const NODE_BUDGET := 60000
const TIME_BUDGET_MS := 2500

var _rng := RandomNumberGenerator.new()
var _nodes := 0
var _deadline := 0
var _stop := false

func _init() -> void:
	_rng.randomize()

func choose_move(board: Array, en_passant: Vector2i, castling: Dictionary, halfmove: int, color: int, difficulty: int) -> Dictionary:
	var pos := {
		"board": (board as Array).duplicate(true),
		"ep": en_passant,
		"castling": (castling as Dictionary).duplicate(),
		"half": halfmove,
	}
	var moves: Array = _gen_moves(pos, color)
	if moves.is_empty():
		return {}
	_shuffle(moves)
	match difficulty:
		Difficulty.EASY:
			return moves[_rng.randi_range(0, moves.size() - 1)]
		Difficulty.MEDIUM:
			if _rng.randf() < 0.10:
				return moves[_rng.randi_range(0, moves.size() - 1)]
			return _greedy(pos, color, moves)
		_:
			return _iterative(pos, color, moves)

func _gen_moves(pos: Dictionary, color: int) -> Array:
	var out: Array = []
	var all: Dictionary = BoardState.all_legal(pos["board"], color, pos["ep"], pos["castling"])
	for f in all:
		var piece: Dictionary = BoardState.get_piece(pos["board"], f)
		var is_pawn: bool = int(piece.get("type", -1)) == BoardState.PieceType.PAWN
		for tt in (all[f] as Array):
			if is_pawn and (tt.y == 0 or tt.y == 7):
				for promo in [BoardState.PieceType.QUEEN, BoardState.PieceType.ROOK, BoardState.PieceType.BISHOP, BoardState.PieceType.KNIGHT]:
					out.append({"from": f, "to": tt, "promotion": promo})
			else:
				out.append({"from": f, "to": tt, "promotion": -1})
	return out

func _make(pos: Dictionary, mv: Dictionary) -> Dictionary:
	var b: Array = pos["board"]
	var f: Vector2i = mv["from"]
	var tt: Vector2i = mv["to"]
	var piece: Dictionary = BoardState.get_piece(b, f)
	var is_pawn: bool = int(piece["type"]) == BoardState.PieceType.PAWN
	var captured: Dictionary = {}
	var target: Dictionary = BoardState.get_piece(b, tt)
	if not target.is_empty():
		captured = target.duplicate()
	elif is_pawn and tt == pos["ep"]:
		captured = BoardState.get_piece(b, Vector2i(tt.x, f.y)).duplicate()
	var u := {"prev_ep": pos["ep"], "prev_castling": (pos["castling"] as Dictionary).duplicate(), "prev_half": int(pos["half"])}
	BoardState.update_castling_on_move(pos["castling"], mv, piece, captured)
	u["record"] = BoardState.apply(b, mv, pos["ep"])
	var new_ep := Vector2i(-1, -1)
	if is_pawn and abs(tt.y - f.y) == 2:
		new_ep = Vector2i(f.x, (f.y + tt.y) >> 1)
	pos["ep"] = new_ep
	if is_pawn or not captured.is_empty():
		pos["half"] = 0
	else:
		pos["half"] = int(pos["half"]) + 1
	return u

func _unmake(pos: Dictionary, u: Dictionary) -> void:
	BoardState.undo(pos["board"], u["record"])
	pos["ep"] = u["prev_ep"]
	pos["castling"] = u["prev_castling"]
	pos["half"] = u["prev_half"]

func _greedy(pos: Dictionary, color: int, moves: Array) -> Dictionary:
	var best: Dictionary = moves[0]
	var best_score := -INF
	for m in moves:
		var u: Dictionary = _make(pos, m)
		var s: int = _evaluate_for(pos, color) + _rng.randi_range(0, 24)
		_unmake(pos, u)
		if s > best_score:
			best_score = s
			best = m
	return best

func _iterative(pos: Dictionary, color: int, moves: Array) -> Dictionary:
	_nodes = 0
	_deadline = Time.get_ticks_msec() + TIME_BUDGET_MS
	_stop = false
	var ordered: Array = _ordered(pos, moves)
	var best: Dictionary = ordered[0]
	var depth := 1
	while depth <= MAX_DEPTH:
		var alpha := -INF
		var depth_best: Dictionary = ordered[0]
		var depth_score := -INF
		var completed := true
		for m in ordered:
			var u: Dictionary = _make(pos, m)
			var s: int = -_search(pos, depth - 1, -INF, -alpha, 1 - color, 1)
			_unmake(pos, u)
			if _stop:
				completed = false
				break
			if s > depth_score:
				depth_score = s
				depth_best = m
			if s > alpha:
				alpha = s
		if not completed:
			break
		best = depth_best
		ordered.erase(best)
		ordered.push_front(best)
		depth += 1
	return best

func _search(pos: Dictionary, depth: int, alpha: int, beta: int, color: int, ply: int) -> int:
	if _stop:
		return 0
	_nodes += 1
	if (_nodes & 1023) == 0 and (Time.get_ticks_msec() > _deadline or _nodes > NODE_BUDGET):
		_stop = true
		return 0
	if int(pos["half"]) >= 100:
		return 0
	var moves: Array = _gen_moves(pos, color)
	if moves.is_empty():
		if BoardState.in_check(pos["board"], color, pos["ep"]):
			return -MATE + ply
		return 0
	if depth <= 0:
		return _quiesce(pos, alpha, beta, color, 0, ply)
	for m in _ordered(pos, moves):
		var u: Dictionary = _make(pos, m)
		var s: int = -_search(pos, depth - 1, -beta, -alpha, 1 - color, ply + 1)
		_unmake(pos, u)
		if _stop:
			return 0
		if s >= beta:
			return beta
		if s > alpha:
			alpha = s
	return alpha

func _quiesce(pos: Dictionary, alpha: int, beta: int, color: int, qply: int, ply: int) -> int:
	if _stop:
		return 0
	_nodes += 1
	if (_nodes & 1023) == 0 and (Time.get_ticks_msec() > _deadline or _nodes > NODE_BUDGET):
		_stop = true
		return 0
	if BoardState.in_check(pos["board"], color, pos["ep"]):
		var evas: Array = _gen_moves(pos, color)
		if evas.is_empty():
			return -MATE + ply
		if qply >= 6:
			return _evaluate_for(pos, color)
		for m in _ordered(pos, evas):
			var ue: Dictionary = _make(pos, m)
			var se: int = -_quiesce(pos, -beta, -alpha, 1 - color, qply + 1, ply + 1)
			_unmake(pos, ue)
			if _stop:
				return 0
			if se >= beta:
				return beta
			if se > alpha:
				alpha = se
		return alpha
	var stand: int = _evaluate_for(pos, color)
	if stand >= beta:
		return beta
	if stand > alpha:
		alpha = stand
	if qply >= 4:
		return alpha
	var all: Array = _gen_moves(pos, color)
	if all.is_empty():
		return 0
	var caps: Array = []
	for m in all:
		if _is_tactical(pos, m):
			caps.append(m)
	for m in _ordered(pos, caps):
		var u: Dictionary = _make(pos, m)
		var s: int = -_quiesce(pos, -beta, -alpha, 1 - color, qply + 1, ply + 1)
		_unmake(pos, u)
		if _stop:
			return 0
		if s >= beta:
			return beta
		if s > alpha:
			alpha = s
	return alpha

func _is_tactical(pos: Dictionary, m: Dictionary) -> bool:
	if int(m["promotion"]) != -1:
		return true
	var to: Vector2i = m["to"]
	if not BoardState.get_piece(pos["board"], to).is_empty():
		return true
	var pc: Dictionary = BoardState.get_piece(pos["board"], m["from"])
	return int(pc.get("type", -1)) == BoardState.PieceType.PAWN and to == pos["ep"]

func _ordered(pos: Dictionary, moves: Array) -> Array:
	var scored: Array = []
	for m in moves:
		var attacker: Dictionary = BoardState.get_piece(pos["board"], m["from"])
		var to: Vector2i = m["to"]
		var key := 0
		var target: Dictionary = BoardState.get_piece(pos["board"], to)
		if not target.is_empty():
			key = int(VAL.get(int(target.get("type", 0)), 0)) * 10 - (int(VAL.get(int(attacker.get("type", 0)), 0)) >> 5)
		elif int(attacker.get("type", -1)) == BoardState.PieceType.PAWN and to == pos["ep"]:
			key = 1000
		if int(m["promotion"]) != -1:
			key += 9000
		key += _rng.randi_range(0, 8)
		scored.append([key, m])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: Array = []
	for s in scored:
		out.append(s[1])
	return out

func _evaluate_for(pos: Dictionary, color: int) -> int:
	var total := 0
	var b: Array = pos["board"]
	var my_king := Vector2i(-1, -1)
	var foe_king := Vector2i(-1, -1)
	var foe_mat := 0
	var mating := false
	var my_minors := 0
	for y in 8:
		for x in 8:
			var pc: Dictionary = b[y][x]
			if pc.is_empty():
				continue
			var t := int(pc["type"])
			var c := int(pc["color"])
			var v: int = int(VAL.get(t, 0)) + _placement(t, c, x, y)
			if c == color:
				total += v
				if t == BoardState.PieceType.KING:
					my_king = Vector2i(x, y)
				elif t == BoardState.PieceType.ROOK or t == BoardState.PieceType.QUEEN:
					mating = true
				elif t == BoardState.PieceType.BISHOP or t == BoardState.PieceType.KNIGHT:
					my_minors += 1
			else:
				total -= v
				if t == BoardState.PieceType.KING:
					foe_king = Vector2i(x, y)
				else:
					foe_mat += int(VAL.get(t, 0))
	if foe_mat == 0 and (mating or my_minors >= 2) and foe_king.x != -1 and my_king.x != -1:
		var edge: int = mini(mini(foe_king.x, 7 - foe_king.x), mini(foe_king.y, 7 - foe_king.y))
		total += (3 - edge) * 50
		var dist: int = abs(my_king.x - foe_king.x) + abs(my_king.y - foe_king.y)
		total += (14 - dist) * 10
	return total

func _placement(t: int, c: int, x: int, y: int) -> int:
	match t:
		BoardState.PieceType.PAWN:
			var adv: int = 6 - y if c == BoardState.PieceColor.WHITE else y - 1
			return maxi(adv, 0) * 10
		BoardState.PieceType.KNIGHT:
			if x >= 2 and x <= 5 and y >= 2 and y <= 5:
				return 20
		BoardState.PieceType.BISHOP:
			if x >= 2 and x <= 5 and y >= 2 and y <= 5:
				return 10
	return 0

func _shuffle(a: Array) -> void:
	var i := a.size() - 1
	while i > 0:
		var j := _rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp
		i -= 1
