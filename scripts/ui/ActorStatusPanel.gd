class_name ActorStatusPanel
extends PanelContainer

@export var accent_color: Color = Color(0.16, 0.78, 0.88)

@onready var actor_name_label: Label = $Content/Heading/ActorName
@onready var hp_value_label: Label = $Content/Heading/HPValue
@onready var hp_bar: ProgressBar = $Content/HPBar
@onready var guard_amount_label: Label = $Content/Resources/Guard/Amount
@onready var energy_amount_label: Label = $Content/Resources/Energy/Amount

func _ready() -> void:
	var panel_style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.border_color = accent_color
	add_theme_stylebox_override("panel", panel_style)
	actor_name_label.add_theme_color_override("font_color", accent_color)
	actor_name_label.add_theme_font_size_override("font_size", 15)
	hp_value_label.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0))
	hp_value_label.add_theme_font_size_override("font_size", 13)
	guard_amount_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
	energy_amount_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))

func update_status(
	actor_name: String,
	current_hp: int,
	max_hp: int,
	guard: int,
	energy: int,
	max_energy: int
) -> void:
	actor_name_label.text = actor_name
	update_hp(current_hp, max_hp)
	guard_amount_label.text = str(maxi(0, guard))
	var safe_max_energy: int = maxi(0, max_energy)
	energy_amount_label.text = "%d/%d" % [
		clampi(energy, 0, safe_max_energy),
		safe_max_energy,
	]

func update_hp(current_hp: int, max_hp: int) -> void:
	var safe_max_hp: int = maxi(1, max_hp)
	var safe_current_hp: int = clampi(current_hp, 0, safe_max_hp)
	hp_bar.max_value = safe_max_hp
	hp_bar.value = safe_current_hp
	hp_value_label.text = "%d/%d" % [safe_current_hp, safe_max_hp]
