class_name DetonationLabel
extends Label

## Floating text that pops, drifts upward and fades out, then frees itself.
## Reusable for any block color: pass the color and the text to show.

const FONT_SIZE := 22
const SUBTITLE_FONT_SIZE := 14

@export var pop_seconds: float = 0.14
@export var hold_seconds: float = 0.25
@export var fade_seconds: float = 0.45
@export var rise_pixels: float = 36.0

# Creates a label centered on `center` (in `parent` local space) and starts it.
# `subtitle` is optional extra context such as a cascade/combo line.
static func spawn(
	parent: Node,
	center: Vector2,
	text: String,
	color: Color,
	subtitle: String = "",
	delay: float = 0.0,
	bounds: Rect2 = Rect2()
) -> DetonationLabel:
	if parent == null:
		return null
	var label := DetonationLabel.new()
	label.text = text if subtitle.is_empty() else "%s\n%s" % [text, subtitle]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 100
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	parent.add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	label.position = center - label.size * 0.5
	if bounds.has_area():
		label.position = _clamp_inside(label.position, label.size, bounds)
	label._play(delay)
	return label

# Keeps the label (including its peak pop scale and upward drift) inside `bounds`.
static func _clamp_inside(pos: Vector2, label_size: Vector2, bounds: Rect2) -> Vector2:
	var peak_scale := 1.25
	var half_extra: Vector2 = label_size * (peak_scale - 1.0) * 0.5
	var min_pos: Vector2 = bounds.position + half_extra
	var max_pos: Vector2 = bounds.end - label_size - half_extra
	# If the label is wider than the bounds, center it instead of overflowing one side.
	var result := pos
	result.x = clampf(pos.x, min_pos.x, max_pos.x) if max_pos.x >= min_pos.x else bounds.get_center().x - label_size.x * 0.5
	result.y = clampf(pos.y, min_pos.y + 36.0, max_pos.y) if max_pos.y >= min_pos.y + 36.0 else pos.y
	return result

func _play(delay: float) -> void:
	scale = Vector2(0.4, 0.4)
	var start_y: float = position.y
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, pop_seconds)
	tween.parallel().tween_property(self, "scale", Vector2(1.25, 1.25), pop_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(hold_seconds)
	tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	tween.parallel().tween_property(self, "position:y", start_y - rise_pixels, fade_seconds + 0.1)
	tween.tween_callback(queue_free)
