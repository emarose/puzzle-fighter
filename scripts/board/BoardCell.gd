class_name BoardCell
extends Resource

@export var position: Vector2i = Vector2i.ZERO
@export var color_id: String = ""
@export var piece_id: String = ""
@export var special_gem_id: String = ""
@export var is_empty: bool = true

func _init(
    p_position: Vector2i = Vector2i.ZERO,
    p_color_id: String = "",
    p_piece_id: String = "",
    p_special_gem_id: String = ""
) -> void:
    position = p_position
    color_id = p_color_id
    piece_id = p_piece_id
    special_gem_id = p_special_gem_id
    is_empty = color_id.is_empty()
