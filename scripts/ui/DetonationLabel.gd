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
	delay: float = 0.0
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
	label._play(delay)
	return label

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
