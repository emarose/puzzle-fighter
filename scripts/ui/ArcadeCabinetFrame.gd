@tool
extends Control

const CABINET_INK := Color(0.025, 0.035, 0.055, 0.96)
const METAL := Color(0.12, 0.17, 0.22, 1.0)

const CORNER_TOP_LEFT := Rect2(538, 80, 112, 112)
const CORNER_TOP_RIGHT := Rect2(665, 80, 106, 112)
const CORNER_BOTTOM_LEFT := Rect2(538, 208, 112, 112)
const CORNER_BOTTOM_RIGHT := Rect2(665, 208, 106, 112)
const CORNER_SCALE := 0.4
const EDGE_INSET := 2.0

@export var atlas_texture: Texture2D

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), CABINET_INK, false, 3.0)
	draw_rect(Rect2(5.0, 5.0, size.x - 10.0, size.y - 10.0), METAL, false, 1.0)
	if atlas_texture == null:
		return

	_draw_corner(CORNER_TOP_LEFT, Vector2(EDGE_INSET, EDGE_INSET), false, false)
	_draw_corner(CORNER_TOP_RIGHT, Vector2(size.x - EDGE_INSET, EDGE_INSET), true, false)
	_draw_corner(CORNER_BOTTOM_LEFT, Vector2(EDGE_INSET, size.y - EDGE_INSET), false, true)
	_draw_corner(CORNER_BOTTOM_RIGHT, Vector2(size.x - EDGE_INSET, size.y - EDGE_INSET), true, true)

func _draw_corner(region: Rect2, anchor: Vector2, from_right: bool, from_bottom: bool) -> void:
	var corner_size := region.size * CORNER_SCALE
	var origin := anchor - Vector2(
		corner_size.x if from_right else 0.0,
		corner_size.y if from_bottom else 0.0
	)
	draw_texture_rect_region(atlas_texture, Rect2(origin, corner_size), region)
