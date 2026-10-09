extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var board_view := BoardView.new()
	var group := MatchManager.PreparedGroup.new(
		1,
		"red",
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	)

	var selected: MatchManager.PreparedGroup = board_view.find_prepared_group_at_screen_position(
		Vector2(60, 60),
		[group]
	)
	assert(selected == group)

	selected = board_view.find_prepared_group_at_screen_position(Vector2(120, 120), [group])
	assert(selected == null)

	print("PreparedGroupTouchTarget_test passed")
	quit()
