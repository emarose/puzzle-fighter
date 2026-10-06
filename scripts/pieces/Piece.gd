class_name Piece
extends RefCounted

var id: String = ""
var color_id: String = ""
var blocks: Array = []
var orientation: int = 0
var logical_position: Vector2i = Vector2i.ZERO
var is_active: bool = false
var is_locked: bool = false
var container_piece: String = ""

func _init(p_id: String = "", p_color_id: String = "", p_logical_position: Vector2i = Vector2i.ZERO, p_blocks: Array = []) -> void:
	id = p_id
	color_id = p_color_id
	logical_position = p_logical_position
	blocks = p_blocks.duplicate(true)
	is_active = true
	is_locked = false

func spawn() -> void:
	is_active = true
	is_locked = false

func lock() -> void:
	is_active = false
	is_locked = true

func destroy() -> void:
	blocks.clear()
	is_active = false
	is_locked = true

func move_left() -> void:
	logical_position.x -= 1

func move_right() -> void:
	logical_position.x += 1

func soft_drop() -> void:
	logical_position.y += 1

func hard_drop() -> void:
	logical_position.y += 1

func rotate_clockwise() -> void:
	orientation = (orientation + 1) % 4
	for index in range(blocks.size()):
		var block: Dictionary = blocks[index]
		var local_position: Vector2i = block.get("local_position", Vector2i.ZERO)
		block["local_position"] = Vector2i(-local_position.y, local_position.x)
		blocks[index] = block

func rotate_counter_clockwise() -> void:
	orientation = (orientation + 3) % 4
	for index in range(blocks.size()):
		var block: Dictionary = blocks[index]
		var local_position: Vector2i = block.get("local_position", Vector2i.ZERO)
		block["local_position"] = Vector2i(local_position.y, -local_position.x)
		blocks[index] = block

func get_block_positions() -> Array:
	var positions: Array = []
	for block in blocks:
		var local_position: Vector2i = block.get("local_position", Vector2i.ZERO)
		positions.append(logical_position + local_position)
	return positions

func get_block_color(index: int) -> String:
	if index < 0 or index >= blocks.size():
		return ""
	return str(blocks[index].get("color_id", color_id))

func get_color_ids() -> Array[String]:
	var colors: Array[String] = []
	for index in range(blocks.size()):
		colors.append(get_block_color(index))
	return colors

func get_block_count() -> int:
	return blocks.size()
