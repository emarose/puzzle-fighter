extends CanvasLayer

@onready var turn_label: Label = $MarginContainer/VBoxContainer/Turn
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/Feedback
@onready var effect_legend: HFlowContainer = $MarginContainer/VBoxContainer/EffectLegend/Items
@onready var special_gem_panel: SpecialGemPanel = $MarginContainer/VBoxContainer/SpecialGemPanel
@onready var special_gem_toast: SpecialGemToast = $MarginContainer/VBoxContainer/SpecialGemToast
@onready var skill_buttons_container: HBoxContainer = $MarginContainer/VBoxContainer/SkillButtons
@onready var mobile_controls: HBoxContainer = $MarginContainer/VBoxContainer/ControlDeck/DeckContent/MobileControls
@onready var joystick: ArcadeJoystick = $MarginContainer/VBoxContainer/ControlDeck/DeckContent/MobileControls/MovementControls
@onready var battle_overlay: BattleOverlay = $BattleOverlay

var skill_buttons: Dictionary = {}
var battle_result_shown: bool = false
var battle_pause_active: bool = false

var battle_manager: Node
var enemy_controller: Node
var battle_controller: Node
var input_controller: Node
var player_status_panel: ActorStatusPanel
var enemy_status_panel: ActorStatusPanel
var event_bus: EventBus

const MOVEMENT_ACCENT := Color(0.16, 0.78, 0.88)
const ACTION_ACCENT := Color(0.91, 0.29, 0.48)
const ENERGY_ACCENT := Color(0.95, 0.68, 0.18)
const PAUSE_ACCENT := Color(0.42, 0.58, 0.72)
const HUD_ATLAS := preload("res://assets/ui/Pixel Sci-Fi HUD Sprite Atlas.png")
const ARCADE_ATLAS := preload("res://assets/ui/Neon Pixel Arcade UI Atlas-1.png")
const SKILL_PLATE_CYAN := Rect2(22, 68, 491, 70)
const SKILL_PLATE_AMBER := Rect2(22, 141, 491, 71)
const ENERGY_ICON_REGION := Rect2(686, 871, 142, 136)
const SKILL_ICON_REGIONS := {
	"burst": Rect2(525, 871, 142, 136),
	"pulse": Rect2(686, 871, 142, 136),
	"heal": Rect2(847, 871, 142, 136),
}
const PAUSE_PATH := "ActionControls/Pause"
const PAUSE_BUTTON_SIZE := 44.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	event_bus = EventBus.get_instance()
	if get_parent() != null:
		battle_manager = get_parent().get_node_or_null("BattleManager")
		enemy_controller = get_parent().get_node_or_null("EnemyController")
		battle_controller = get_parent()
		input_controller = get_parent().get_node_or_null("InputController")
		player_status_panel = get_parent().get_node_or_null(
			"PlayerBoardContainer/ActorStatusPanel"
		) as ActorStatusPanel
		enemy_status_panel = get_parent().get_node_or_null(
			"EnemyBoardContainer/ActorStatusPanel"
		) as ActorStatusPanel

	if battle_manager != null and battle_manager.has_signal("state_changed"):
		battle_manager.state_changed.connect(_on_state_changed)
	if event_bus != null:
		event_bus.event_emitted.connect(_on_event_emitted)
	if input_controller != null:
		_connect_mobile_controls()
		joystick.direction_changed.connect(_on_joystick_direction_changed)
		joystick.direction_repeated.connect(_on_joystick_direction_repeated)
		if input_controller.has_signal("pause_requested"):
			input_controller.pause_requested.connect(_on_pause_requested)
	if battle_overlay != null:
		battle_overlay.resume_requested.connect(_on_resume_requested)
		battle_overlay.restart_requested.connect(_on_restart_requested)

	_build_effect_legend()
	call_deferred("_build_skill_buttons")
	call_deferred("_configure_special_gem_panel")
	get_viewport().size_changed.connect(_apply_control_dimensions)
	_apply_control_dimensions()
	_update_hud()
	_update_state_summary()

func _exit_tree() -> void:
	if battle_pause_active and get_tree() != null:
		get_tree().paused = false
		battle_pause_active = false

func _on_state_changed(_old_state: int, _new_state: int) -> void:
	_update_hud()
	_update_state_summary()

func _on_skill_button_pressed(skill_id: String) -> void:
	if input_controller == null or not input_controller.has_method("try_use_skill"):
		return
	if not input_controller.call("try_use_skill", skill_id):
		return
	_update_hud()

func _build_effect_legend() -> void:
	var palette: Dictionary = ColorDefinition.default_palette()
	for color_id in ["red", "blue", "green", "yellow"]:
		var definition: ColorDefinition = palette[color_id]
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(11, 11)
		swatch.color = definition.display_color
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(swatch)

		var label := Label.new()
		label.text = definition.get_role_label().to_upper()
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.82, 0.89, 0.96))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(label)
		effect_legend.add_child(item)

func _connect_mobile_controls() -> void:
	var controls: Dictionary = {
		"ActionControls/Rotate": "try_rotate",
		"ActionControls/HardDrop": "try_hard_drop",
		PAUSE_PATH: "try_pause",
	}
	for button_path: String in controls:
		var button: Button = _get_action_button(button_path)
		var method_name: String = controls[button_path]
		if input_controller.has_method(method_name):
			button.pressed.connect(Callable(input_controller, method_name))

func _on_joystick_direction_changed(direction: StringName) -> void:
	if direction == &"":
		return
	_execute_joystick_direction(direction)

func _on_joystick_direction_repeated(direction: StringName) -> void:
	_execute_joystick_direction(direction)

func _execute_joystick_direction(direction: StringName) -> void:
	if input_controller == null or get_tree().paused:
		return
	match direction:
		&"left":
			input_controller.call("try_move_left")
		&"right":
			input_controller.call("try_move_right")
		&"down":
			input_controller.call("try_soft_drop")

func _build_skill_buttons() -> void:
	if battle_controller == null or not battle_controller.has_method("get_player_skill_definitions"):
		return
	skill_buttons.clear()
	for child in skill_buttons_container.get_children():
		child.queue_free()
	var skill_definitions: Array[SkillDefinition] = battle_controller.get_player_skill_definitions()
	for index in range(skill_definitions.size()):
		var definition: SkillDefinition = skill_definitions[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = definition.name
		button.set_meta("cost_text", "%d" % definition.cost)
		button.tooltip_text = definition.description
		_style_skill_button(button, definition.id)
		button.pressed.connect(_on_skill_button_pressed.bind(definition.id))
		skill_buttons_container.add_child(button)
		skill_buttons[definition.id] = button
	_update_skill_buttons()

func _style_skill_button(button: Button, skill_id: String) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_stylebox_override("normal", _make_skill_plate(SKILL_PLATE_CYAN))
	button.add_theme_stylebox_override("hover", _make_skill_plate(SKILL_PLATE_CYAN))
	button.add_theme_stylebox_override("pressed", _make_skill_plate(SKILL_PLATE_AMBER))
	button.add_theme_stylebox_override("disabled", _make_skill_plate(SKILL_PLATE_CYAN))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.55))
	button.add_theme_color_override("font_disabled_color", Color(0.85, 0.92, 1.0))
	button.add_theme_font_size_override("font_size", 12)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	center.add_child(row)
	if SKILL_ICON_REGIONS.has(skill_id):
		var icon := AtlasTexture.new()
		icon.atlas = ARCADE_ATLAS
		icon.region = SKILL_ICON_REGIONS[skill_id]
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_rect)
	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	var name_label := Label.new()
	name_label.text = button.text
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(name_label)
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_theme_constant_override("separation", 2)
	labels.add_child(cost_row)
	var cost_label := Label.new()
	cost_label.text = button.get_meta("cost_text", "")
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(cost_label)
	var energy_atlas := AtlasTexture.new()
	energy_atlas.atlas = ARCADE_ATLAS
	energy_atlas.region = ENERGY_ICON_REGION
	var energy_icon := TextureRect.new()
	energy_icon.texture = energy_atlas
	energy_icon.custom_minimum_size = Vector2(13, 13)
	energy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	energy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	energy_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(energy_icon)
	button.text = ""
	button.add_child(center)
	button.set_meta("labels", [name_label, cost_label])

func _make_skill_plate(region: Rect2) -> StyleBoxTexture:
	var plate := AtlasTexture.new()
	plate.atlas = ARCADE_ATLAS
	plate.region = region
	var style := StyleBoxTexture.new()
	style.texture = plate
	style.texture_margin_left = 24.0
	style.texture_margin_right = 24.0
	style.texture_margin_top = 18.0
	style.texture_margin_bottom = 18.0
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style

func _skill_accent(index: int) -> Color:
	match index % 3:
		0:
			return ACTION_ACCENT
		1:
			return ENERGY_ACCENT
		_:
			return MOVEMENT_ACCENT

func _apply_control_dimensions() -> void:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var control_size: float = clampf(viewport_width * 0.17, 80.0, 96.0)
	var joystick_width: float = clampf(viewport_width * 0.30, 140.0, 170.0)
	var joystick_height: float = clampf(viewport_width * 0.28, 130.0, 150.0)
	joystick.custom_minimum_size = Vector2(joystick_width, joystick_height)
	for path: String in ["ActionControls/Rotate", "ActionControls/HardDrop", PAUSE_PATH]:
		var button := _get_action_button(path)
		var button_size: float = PAUSE_BUTTON_SIZE if path == PAUSE_PATH else control_size
		button.custom_minimum_size = Vector2(button_size, button_size)
		button.add_theme_constant_override("icon_max_width", int(button_size - 4.0))
		_style_arcade_button(button, _action_accent(path), true, true)
		if not button.has_meta("arcade_art_feedback_connected"):
			button.mouse_entered.connect(_on_action_button_hovered.bind(button))
			button.mouse_exited.connect(_on_action_button_idle.bind(button))
			button.button_down.connect(_on_action_button_pressed.bind(button))
			button.button_up.connect(_on_action_button_idle.bind(button))
			button.set_meta("arcade_art_feedback_connected", true)

func _get_action_button(path: String) -> Button:
	return mobile_controls.get_node(path) as Button

func _on_action_button_hovered(button: Button) -> void:
	button.self_modulate = Color(1.12, 1.12, 1.12, 1.0)

func _on_action_button_pressed(button: Button) -> void:
	button.self_modulate = Color(0.76, 0.82, 0.92, 1.0)

func _on_action_button_idle(button: Button) -> void:
	button.self_modulate = Color.WHITE

func _action_accent(button_path: String) -> Color:
	match button_path:
		"ActionControls/Rotate":
			return ACTION_ACCENT
		"ActionControls/HardDrop":
			return ENERGY_ACCENT
		_:
			return PAUSE_ACCENT

func _style_arcade_button(
	button: Button,
	accent: Color,
	circular: bool = false,
	use_artwork: bool = false
) -> void:
	var diameter: float = button.custom_minimum_size.x
	if use_artwork:
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	else:
		button.add_theme_stylebox_override("normal", _make_button_style(accent, "normal", circular, diameter))
		button.add_theme_stylebox_override("hover", _make_button_style(accent, "hover", circular, diameter))
		button.add_theme_stylebox_override("pressed", _make_button_style(accent, "pressed", circular, diameter))
		button.add_theme_stylebox_override("disabled", _make_button_style(accent, "disabled", circular, diameter))
	button.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.55, 0.62))
	button.add_theme_font_size_override("font_size", 11 if circular else 14)

func _make_button_style(accent: Color, state: String, circular: bool = false, diameter: float = 68.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.09, 0.13, 0.98)
	style.border_color = accent
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	var radius := int(diameter * 0.5) if circular else 7
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 2
	match state:
		"hover":
			style.bg_color = Color(0.09, 0.15, 0.20, 1.0)
			style.border_color = accent.lightened(0.18)
		"pressed":
			style.bg_color = accent.darkened(0.68)
			style.border_color = accent.lightened(0.24)
			style.shadow_size = 0
		"disabled":
			style.bg_color = Color(0.07, 0.085, 0.10, 0.96)
			style.border_color = Color(0.28, 0.34, 0.39, 0.8)
			style.shadow_size = 0
	return style

func _configure_special_gem_panel() -> void:
	if special_gem_panel == null or battle_controller == null:
		return
	if not battle_controller.has_method("get_player_special_gems"):
		return
	special_gem_panel.configure(
		battle_controller.get_player_special_gems(),
		battle_controller.get_skill_energy()
	)

func _on_event_emitted(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"battle_state_changed":
			_update_hud()
			_update_state_summary()
		"hp_changed":
			_update_hp_from_event(payload)
		"skill_energy_changed", "guard_applied", "guard_absorbed":
			_update_hud()
		"cascade_finished":
			var cascades: int = int(payload.get("cascade_count", 0))
			if cascades > 0:
				_set_feedback("%s: %d-wave chain, %d blocks" % [
					_actor_name(str(payload.get("actor_id", ""))),
					cascades,
					int(payload.get("total_blocks", 0)),
				])
		"skill_used":
			_update_hud()
			_set_feedback("%s used %s" % [
				_actor_name(str(payload.get("actor_id", ""))),
				str(payload.get("skill_id", "")).replace("_", " ").capitalize(),
			])
		"special_gem_activated":
			_update_hud()
			_show_special_gem_toast(payload)
		"attack_created":
			_set_feedback("%s: %s %d" % [
				_actor_name(str(payload.get("source", ""))),
				str(payload.get("role", "damage")).capitalize(),
				int(payload.get("amount", 0)),
			])
		"damage_received":
			_set_feedback("%s took %d damage" % [
				_actor_name(str(payload.get("actor_id", ""))),
				int(payload.get("amount", 0)),
			])
		"enemy_action_finished":
			_update_hud()
			_update_state_summary()

func _show_special_gem_toast(payload: Dictionary) -> void:
	if special_gem_toast == null:
		return
	var gem_id: String = str(payload.get("gem_id", ""))
	var gem_name: String = gem_id.replace("_", " ").capitalize()
	var color := Color.WHITE
	if battle_controller != null and battle_controller.has_method("get_player_special_gems"):
		for gem in battle_controller.get_player_special_gems():
			if gem.id == gem_id:
				gem_name = gem.display_name
				color = SpecialGemGlyph.color_for_id(gem.color_id)
	var effect: String
	match str(payload.get("effect_type", "")):
		"critical_chance":
			effect = "Critical hit x%.1f" % float(payload.get("multiplier", 1.0))
		"fireball":
			effect = "%d damage to enemy" % int(payload.get("amount", 0))
		"barrier":
			effect = "+%d Guard" % int(payload.get("amount", 0))
		_:
			effect = "Activated"
	special_gem_toast.show_line("%s: %s" % [gem_name, effect], color)

func _set_feedback(message: String) -> void:
	feedback_label.text = message

func _actor_name(actor_id: String) -> String:
	if enemy_controller != null:
		if actor_id == enemy_controller.player_state.actor_id:
			return _get_player_name()
		if actor_id == enemy_controller.enemy_state.actor_id:
			return _get_enemy_name()
	return actor_id.capitalize() if not actor_id.is_empty() else "Battle"

func _on_pause_requested() -> void:
	if battle_manager == null or get_tree() == null:
		return
	if battle_manager.current_state in [
		BattleManager.BattleState.VICTORY,
		BattleManager.BattleState.DEFEAT,
	]:
		return
	if battle_pause_active:
		_on_resume_requested()
		return
	battle_overlay.show_pause()
	battle_pause_active = true
	get_tree().paused = true

func _on_resume_requested() -> void:
	if battle_pause_active and get_tree() != null:
		get_tree().paused = false
	battle_pause_active = false
	battle_overlay.hide_overlay()
	_update_state_summary()

func _on_restart_requested() -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		push_error("Cannot restart the battle because the scene tree is unavailable.")
		return
	var error: Error = scene_tree.reload_current_scene()
	if error != OK:
		push_error("Failed to restart the battle: %s" % error_string(error))

func _show_battle_result(is_victory: bool) -> void:
	if battle_pause_active and get_tree() != null:
		get_tree().paused = false
		battle_pause_active = false
	if battle_result_shown:
		return
	battle_result_shown = true
	battle_overlay.show_result(is_victory)
	_set_feedback("Victory" if is_victory else "Defeat")

func _update_state_summary() -> void:
	if battle_manager == null:
		return
	if battle_manager.current_state == BattleManager.BattleState.VICTORY:
		_show_battle_result(true)
	elif battle_manager.current_state == BattleManager.BattleState.DEFEAT:
		_show_battle_result(false)

func _update_hp_from_event(payload: Dictionary) -> void:
	var player_actor_id: String = "player"
	var enemy_actor_id: String = "enemy"
	if enemy_controller != null:
		player_actor_id = enemy_controller.player_state.actor_id
		enemy_actor_id = enemy_controller.enemy_state.actor_id
	if payload.get("actor_id", "") == player_actor_id:
		var player_max_hp: int = enemy_controller.player_state.max_hp if enemy_controller != null else 0
		if player_status_panel != null:
			player_status_panel.update_hp(int(payload.get("current_hp", 0)), player_max_hp)
	elif payload.get("actor_id", "") == enemy_actor_id:
		var enemy_max_hp: int = enemy_controller.enemy_state.max_hp if enemy_controller != null else 0
		if enemy_status_panel != null:
			enemy_status_panel.update_hp(int(payload.get("current_hp", 0)), enemy_max_hp)

func _update_hud() -> void:
	if enemy_controller != null and enemy_controller.has_method("get_current_attack_preview"):
		turn_label.text = "Turn %d  |  Enemy: %s" % [
			enemy_controller.turn_counter,
			enemy_controller.get_current_attack_preview(),
		]
	else:
		turn_label.text = "Turn 0"

	if player_status_panel != null and enemy_controller != null and enemy_controller.get("player_state") != null:
		var player_state: CombatState = enemy_controller.get("player_state")
		player_status_panel.update_status(
			_get_player_name(),
			player_state.current_hp,
			player_state.max_hp,
			battle_controller.get_player_guard(),
			battle_controller.get_skill_energy(),
			battle_controller.get_max_energy()
		)
	if enemy_status_panel != null and enemy_controller != null and enemy_controller.get("enemy_state") != null:
		var enemy_state: CombatState = enemy_controller.get("enemy_state")
		enemy_status_panel.update_status(
			_get_enemy_name(),
			enemy_state.current_hp,
			enemy_state.max_hp,
			battle_controller.get_enemy_guard(),
			battle_controller.get_enemy_energy(),
			battle_controller.get_max_energy()
		)
	if special_gem_panel != null and battle_controller != null:
		special_gem_panel.set_energy(battle_controller.get_skill_energy())
	_update_skill_buttons()

func _get_player_name() -> String:
	if battle_manager != null and battle_manager.player_character != null:
		return battle_manager.player_character.name
	return "Player"

func _get_enemy_name() -> String:
	if battle_manager != null and battle_manager.enemy_character != null:
		return battle_manager.enemy_character.name
	return "Enemy"

func _update_skill_buttons() -> void:
	if battle_controller == null or not battle_controller.has_method("can_use_skill"):
		for button in skill_buttons.values():
			button.disabled = true
		return
	for skill_id in skill_buttons:
		var button: Button = skill_buttons[skill_id]
		var ready: bool = battle_controller.can_use_skill(skill_id)
		button.disabled = not ready
		var plate_region: Rect2 = SKILL_PLATE_AMBER if ready else SKILL_PLATE_CYAN
		button.add_theme_stylebox_override("normal", _make_skill_plate(plate_region))
		button.add_theme_stylebox_override("hover", _make_skill_plate(plate_region))
		button.add_theme_stylebox_override("disabled", _make_skill_plate(plate_region))
		var text_color := Color(1.0, 0.9, 0.55) if ready else Color(0.91, 0.95, 1.0)
		for label: Label in button.get_meta("labels", []):
			label.add_theme_color_override("font_color", text_color)
		button.self_modulate = Color(1.2, 1.2, 1.2) if ready else Color.WHITE
