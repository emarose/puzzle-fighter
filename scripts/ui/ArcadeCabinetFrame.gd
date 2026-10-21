@tool
extends Control

const CABINET_INK := Color(0.025, 0.035, 0.055, 0.96)
const METAL := Color(0.12, 0.17, 0.22, 1.0)
const RAIL_HIGHLIGHT := Color(0.25, 0.34, 0.40, 0.9)
const CYAN := Color(0.08, 0.64, 0.82, 0.85)
const MAGENTA := Color(0.78, 0.15, 0.38, 0.85)

@export var cyan_panel_texture: Texture2D
@export var magenta_panel_texture: Texture2D

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	draw_rect(bounds, CABINET_INK, false, 3.0)
	draw_rect(Rect2(5.0, 5.0, size.x - 10.0, size.y - 10.0), METAL, false, 1.0)

	var rail_width := minf(8.0, size.x * 0.018)
	var rail_height := size.y * 0.32
	draw_rect(Rect2(2.0, size.y * 0.12, rail_width, rail_height), CYAN)
	draw_rect(Rect2(size.x - rail_width - 2.0, size.y * 0.12, rail_width, rail_height), CYAN)
	draw_rect(Rect2(2.0, size.y * 0.62, rail_width, size.y * 0.24), MAGENTA)
	draw_rect(Rect2(size.x - rail_width - 2.0, size.y * 0.62, rail_width, size.y * 0.24), MAGENTA)

	var panel_width := minf(size.x - 24.0, 516.0)
	var panel_height := panel_width * cyan_panel_texture.get_height() / cyan_panel_texture.get_width()
	var panel_x := (size.x - panel_width) * 0.5
	draw_texture_rect(
		cyan_panel_texture,
		Rect2(panel_x, 4.0, panel_width, panel_height),
		false
	)
	draw_texture_rect(
		magenta_panel_texture,
		Rect2(panel_x, maxf(4.0, size.y - panel_height - 4.0), panel_width, panel_height),
		false
	)

	var bolt_radius := 2.5
	for point in [
		Vector2(10.0, 16.0),
		Vector2(size.x - 10.0, 16.0),
		Vector2(10.0, size.y - 18.0),
		Vector2(size.x - 10.0, size.y - 18.0),
	]:
		draw_circle(point, bolt_radius + 1.0, CABINET_INK)
		draw_circle(point, bolt_radius, RAIL_HIGHLIGHT)
