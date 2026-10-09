extends SceneTree

class EnemyTurnBattleManager:
	extends Node

	func can_player_act() -> bool:
		return false

	func can_enemy_act() -> bool:
		return true

class TapTargetBattleController:
	extends Node

	var tap_count: int = 0

	func try_resolve_prepared_group_at_screen_position(_screen_position: Vector2) -> bool:
		tap_count += 1
		return true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle_controller := TapTargetBattleController.new()
	var battle_manager := EnemyTurnBattleManager.new()
	battle_manager.name = "BattleManager"
	battle_controller.add_child(battle_manager)

	var input_controller := InputController.new()
	input_controller.name = "InputController"
	battle_controller.add_child(input_controller)
	root.add_child(battle_controller)
	await process_frame

	_simulate_tap(input_controller, Vector2(100, 100))
	assert(battle_controller.tap_count == 1)

	print("PreparedGroupEnemyTurnInput_test passed")
	quit()

func _simulate_tap(input_controller: InputController, position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = position
	input_controller._unhandled_input(press)

	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = position
	input_controller._unhandled_input(release)
