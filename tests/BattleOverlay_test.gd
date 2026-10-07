extends SceneTree

var restart_requested_count: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var overlay_scene: PackedScene = load("res://scenes/ui/BattleOverlay.tscn")
	assert(overlay_scene != null)
	var overlay: BattleOverlay = overlay_scene.instantiate()
	root.add_child(overlay)
	overlay.restart_requested.connect(_on_restart_requested)
	await process_frame

	var resume_button: Button = overlay.get_node("Center/Panel/Content/Resume")
	var restart_button: Button = overlay.get_node("Center/Panel/Content/Restart")

	overlay.show_pause()
	assert(resume_button.visible)
	assert(not restart_button.visible)

	overlay.show_result(true)
	assert(overlay.get_node("Center/Panel/Content/Heading").text == "Victory")
	assert(not resume_button.visible)
	assert(restart_button.visible)
	restart_button.pressed.emit()
	assert(restart_requested_count == 1)

	overlay.show_result(false)
	assert(overlay.get_node("Center/Panel/Content/Heading").text == "Defeat")
	assert(restart_button.visible)

	print("BattleOverlay_test passed")
	quit()

func _on_restart_requested() -> void:
	restart_requested_count += 1
