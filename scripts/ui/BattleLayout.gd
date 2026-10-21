extends Node

const BOARD_SIZE := Vector2(240.0, 400.0)
const SIDE_MARGIN := 18.0
const MAX_BOARD_GAP := 36.0
const RESERVED_BOTTOM_SPACE := 280.0

@onready var player_board: Node2D = get_parent().get_node("PlayerBoardContainer")
@onready var enemy_board: Node2D = get_parent().get_node("EnemyBoardContainer")

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_layout)
	call_deferred("_apply_layout")

func _apply_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var board_gap: float = minf(MAX_BOARD_GAP, viewport_size.x * 0.0667)
	var horizontal_scale: float = (
		(viewport_size.x - SIDE_MARGIN * 2.0 - board_gap) / (BOARD_SIZE.x * 2.0)
	)
	var board_top: float = maxf(140.0, viewport_size.y * 0.30)
	var available_board_height: float = viewport_size.y - RESERVED_BOTTOM_SPACE - board_top
	var vertical_scale: float = available_board_height / BOARD_SIZE.y
	var board_scale: float = clampf(minf(horizontal_scale, vertical_scale), 0.1, 1.0)
	var scaled_width: float = BOARD_SIZE.x * board_scale
	var total_width: float = scaled_width * 2.0 + board_gap
	var board_left: float = (viewport_size.x - total_width) * 0.5

	player_board.position = Vector2(board_left, board_top)
	enemy_board.position = Vector2(board_left + scaled_width + board_gap, board_top)
	player_board.scale = Vector2.ONE * board_scale
	enemy_board.scale = Vector2.ONE * board_scale
