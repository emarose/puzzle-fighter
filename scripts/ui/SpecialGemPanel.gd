class_name SpecialGemPanel
extends PanelContainer

# Self-contained widget: lists the equipped special gems grouped by color.
# It only consumes plain data via configure()/set_energy(), so it can be moved anywhere.

const COLOR_ORDER: Array[String] = ["red", "yellow", "blue", "green"]
const DIM_ALPHA := 0.4
const ICON_SIZE := 18

var _rows: Dictionary = {}
var _gem_entries: Array = []
var _energy: int = 0

func configure(gems: Array[SpecialGemDefinition], energy: int = 0) -> void:
	_energy = energy
	_rebuild(gems)

func set_energy(energy: int) -> void:
	_energy = energy
	_refresh_availability()

func _rebuild(gems: Array[SpecialGemDefinition]) -> void:
	for child in get_children():
		child.queue_free()
	_rows.clear()
	_gem_entries.clear()

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)

	for color_id in COLOR_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		column.add_child(row)
		row.add_child(_make_color_chip(color_id))
		var matching: Array[SpecialGemDefinition] = []
		for gem in gems:
			if gem.color_id == color_id:
				matching.append(gem)
		if matching.is_empty():
			row.add_child(_make_label("-", Color(1, 1, 1, 0.35)))
		for gem in matching:
			var entry: Control = _make_gem_entry(gem)
			row.add_child(entry)
			_gem_entries.append({"gem": gem, "control": entry})
		_rows[color_id] = row
	_refresh_availability()

func _make_color_chip(color_id: String) -> Control:
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(14, 14)
	chip.color = SpecialGemGlyph.color_for_id(color_id)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip

func _make_gem_entry(gem: SpecialGemDefinition) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.tooltip_text = gem.display_name
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	if gem.icon != null:
		var icon := TextureRect.new()
		icon.texture = gem.icon
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	row.add_child(_make_label("%s %s" % [gem.display_name, gem.get_requirement_text()], Color.WHITE))
	return row

func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _refresh_availability() -> void:
	for entry in _gem_entries:
		var gem: SpecialGemDefinition = entry["gem"]
		var control: Control = entry["control"]
		control.modulate.a = 1.0 if _energy >= gem.energy_cost else DIM_ALPHA
