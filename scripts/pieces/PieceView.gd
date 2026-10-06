class_name PieceView
extends Node2D

var piece: Piece
var cell_size: Vector2 = Vector2(32, 32)

func show_piece(p_piece: Piece) -> void:
	piece = p_piece
	queue_redraw()

func clear_piece() -> void:
	piece = null
	queue_redraw()

func _draw() -> void:
	if piece == null:
		return

	for index in range(piece.blocks.size()):
		var block: Dictionary = piece.blocks[index]
		var local_position: Vector2i = block.get("local_position", Vector2i.ZERO)
		var world_position: Vector2i = piece.logical_position + local_position
		var color: Color = color_for_id(piece.get_block_color(index))
		var rect := Rect2(
			Vector2(world_position.x * cell_size.x + 4, world_position.y * cell_size.y + 4),
			cell_size - Vector2(8, 8)
		)
		draw_rect(rect, color)

func color_for_id(color_id: String) -> Color:
	match color_id:
		"red":
			return Color(0.94, 0.31, 0.36, 1.0)
		"blue":
			return Color(0.36, 0.61, 1.0, 1.0)
		"green":
			return Color(0.39, 0.82, 0.56, 1.0)
		"yellow":
			return Color(1.0, 0.86, 0.25, 1.0)
		_:
			return Color(0.75, 0.75, 0.75, 1.0)
