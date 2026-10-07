extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle_scene: PackedScene = load("res://scenes/battle/Battle.tscn")
	assert(battle_scene != null)
	var battle: Variant = battle_scene.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	await process_frame

	var input_controller: InputController = battle.get_node("InputController") as InputController
	assert(battle.active_piece != null)

	var piece: Piece = battle.active_piece
	var start_position: Vector2i = piece.logical_position
	_simulate_swipe(input_controller, Vector2(100, 100), Vector2(180, 100))
	assert(piece.logical_position == start_position + Vector2i(1, 0))

	start_position = piece.logical_position
	_simulate_swipe(input_controller, Vector2(100, 100), Vector2(20, 100))
	assert(piece.logical_position == start_position + Vector2i(-1, 0))

	start_position = piece.logical_position
	_simulate_swipe(input_controller, Vector2(100, 100), Vector2(100, 180))
	assert(piece.logical_position == start_position + Vector2i(0, 1))

	var orientation: int = piece.orientation
	_simulate_swipe(input_controller, Vector2(100, 100), Vector2(100, 20))
	assert(piece.orientation == (orientation + 1) % 4)

	start_position = piece.logical_position
	_simulate_swipe(input_controller, Vector2(100, 100), Vector2(120, 120))
	assert(piece.logical_position == start_position)

	var rotate_button: Button = battle.get_node(
		"BattleHud/MarginContainer/VBoxContainer/MobileControls/ActionControls/Rotate"
	)
	orientation = piece.orientation
	rotate_button.pressed.emit()
	assert(piece.orientation == (orientation + 1) % 4)
	rotate_button.pressed.emit()
	rotate_button.pressed.emit()
	assert(piece.orientation == (orientation + 3) % 4)

	var left_button: Button = battle.get_node(
		"BattleHud/MarginContainer/VBoxContainer/MobileControls/MovementControls/MoveLeft"
	)
	start_position = piece.logical_position
	left_button.pressed.emit()
	assert(piece.logical_position == start_position + Vector2i(-1, 0))

	var right_button: Button = battle.get_node(
		"BattleHud/MarginContainer/VBoxContainer/MobileControls/MovementControls/MoveRight"
	)
	start_position = piece.logical_position
	right_button.pressed.emit()
	assert(piece.logical_position == start_position + Vector2i(1, 0))

	var soft_drop_button: Button = battle.get_node(
		"BattleHud/MarginContainer/VBoxContainer/MobileControls/MovementControls/SoftDrop"
	)
	start_position = piece.logical_position
	soft_drop_button.pressed.emit()
	assert(piece.logical_position == start_position + Vector2i(0, 1))

	var pause_button: Button = battle.get_node(
		"BattleHud/MarginContainer/VBoxContainer/MobileControls/ActionControls/Pause"
	)
	pause_button.pressed.emit()
	assert(paused)
	var resume_button: Button = battle.get_node("BattleHud/BattleOverlay/Center/Panel/Content/Resume")
	resume_button.pressed.emit()
	assert(not paused)

	var hard_drop_button: Button = battle.get_node(
		"BattleHud/MarginContainer/VBoxContainer/MobileControls/ActionControls/HardDrop"
	)
	hard_drop_button.pressed.emit()
	await process_frame
	await process_frame
	assert(piece.is_locked)

	print("MobileInput_test passed")
	quit()

func _simulate_swipe(
	input_controller: InputController,
	start_position: Vector2,
	end_position: Vector2
) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = start_position
	input_controller._unhandled_input(press)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = end_position
	input_controller._unhandled_input(drag)

	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = end_position
	input_controller._unhandled_input(release)
