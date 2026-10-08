class_name SpecialGemGlyph
extends RefCounted

# Shared drawing for special gems so board, active piece and HUD look identical.
enum Status { IDLE, READY, BLOCKED }

const READY_COLOR := Color(0.35, 1.0, 0.5, 1.0)
const BLOCKED_COLOR := Color(0.35, 0.35, 0.4, 1.0)
const IDLE_COLOR := Color(1, 1, 1, 1)
const INK_COLOR := Color(0.08, 0.08, 0.12, 1.0)

static func color_for_id(color_id: String) -> Color:
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

static func status_color(status: int) -> Color:
	match status:
		Status.READY:
			return READY_COLOR
		Status.BLOCKED:
			return BLOCKED_COLOR
		_:
			return IDLE_COLOR

# Draws a badge with the gem initial inside `rect` plus a status border.
static func draw_badge(canvas: CanvasItem, rect: Rect2, label: String, status: int) -> void:
	var badge: Rect2 = rect.grow(-rect.size.x * 0.18)
	var accent: Color = status_color(status)
	canvas.draw_rect(badge, Color(0.08, 0.08, 0.12, 0.85))
	canvas.draw_rect(badge, accent, false, 2.0 if status == Status.READY else 1.5)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(max(10.0, badge.size.y * 0.8))
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := Vector2(
		badge.get_center().x - text_size.x * 0.5,
		badge.get_center().y + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.25
	)
	canvas.draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent)
