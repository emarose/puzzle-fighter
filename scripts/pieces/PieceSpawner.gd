class_name PieceSpawner
extends RefCounted

var next_piece_id: int = 0

func create_piece(color_id: String, logical_position: Vector2i = Vector2i.ZERO, shape: Array = [Vector2i(0, 0), Vector2i(1, 0)]) -> Piece:
	var blocks: Array = []
	for index in range(shape.size()):
		var offset: Vector2i = shape[index]
		blocks.append({
			"color_id": color_id,
			"type": "pair",
			"owner_piece": "",
			"local_position": offset,
			"state": "active",
		})

	var piece := Piece.new("piece_%d" % next_piece_id, color_id, logical_position, blocks)
	piece.container_piece = "pair"
	next_piece_id += 1
	return piece
