class_name SpecialGemToast
extends VBoxContainer

# Self-contained feedback banner. It only displays lines it is given via show_line().

const MAX_LINES := 3
const HOLD_SECONDS := 1.6
const FADE_SECONDS := 0.5

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER

func show_line(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	while get_child_count() > MAX_LINES:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	_restart_fade()

func clear_lines() -> void:
	for child in get_children():
		child.queue_free()

func _restart_fade() -> void:
	if _tween != null:
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(clear_lines)
