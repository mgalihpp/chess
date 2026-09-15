class_name ChessPiece
extends Node2D

const SQ: int = 64
const GLYPH_W: Array = ["\u2659", "\u2658", "\u2657", "\u2656", "\u2655", "\u2654"]
const GLYPH_B: Array = ["\u265F", "\u265E", "\u265D", "\u265C", "\u265B", "\u265A"]

var piece_type: int = 0
var piece_color: int = 0
var _label: Label

static func glyph(t: int, c: int) -> String:
	if t < 0 or t > 5:
		return "?"
	if c == BoardState.PieceColor.WHITE:
		return GLYPH_W[t]
	return GLYPH_B[t]

func setup(t: int, c: int) -> void:
	piece_type = t
	piece_color = c
	_ensure_label()
	_label.text = glyph(t, c)
	_label.add_theme_color_override("font_color", Color("#1a1a1a") if c == BoardState.PieceColor.WHITE else Color("#f5f5f5"))
	queue_redraw()

func _ready() -> void:
	_ensure_label()

func _ensure_label() -> void:
	if _label != null and is_instance_valid(_label):
		return
	_label = Label.new()
	_label.name = "Glyph"
	_label.size = Vector2(SQ, SQ)
	_label.position = Vector2.ZERO
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 44)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _draw() -> void:
	var base := Color("#f8e7c8") if piece_color == BoardState.PieceColor.WHITE else Color("#3b3f4a")
	draw_circle(Vector2(SQ * 0.5, SQ * 0.5), 26.0, base)
	draw_arc(Vector2(SQ * 0.5, SQ * 0.5), 26.0, 0.0, TAU, 32, Color("#222222"), 2.0)
