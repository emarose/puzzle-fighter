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

# Maps gem id -> icon so views only receive plain presentation data.
static func icons_by_id(gems: Array[SpecialGemDefinition]) -> Dictionary:
	var icons: Dictionary = {}
	for gem in gems:
		icons[gem.id] = gem.icon
	return icons

# Draws the gem icon fitted (aspect preserved) inside `rect` plus a status border.
static func draw_badge(canvas: CanvasItem, rect: Rect2, icon: Texture2D, status: int) -> void:
	var accent: Color = status_color(status)
	canvas.draw_rect(rect, Color(0.08, 0.08, 0.12, 0.85))
	if icon != null:
		var icon_rect: Rect2 = fit_rect(icon.get_size(), rect.grow(-rect.size.x * 0.08))
		canvas.draw_texture_rect(icon, icon_rect, false)
	canvas.draw_rect(rect, accent, false, 2.0 if status == Status.READY else 1.5)

# Largest rect with the texture's aspect ratio that fits centered in `bounds`.
static func fit_rect(texture_size: Vector2, bounds: Rect2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return bounds
	var scale: float = min(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
	var fitted: Vector2 = texture_size * scale
	return Rect2(bounds.get_center() - fitted * 0.5, fitted)
