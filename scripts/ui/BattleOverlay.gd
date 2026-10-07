class_name BattleOverlay
extends Control

signal resume_requested
signal restart_requested

@onready var heading: Label = $Center/Panel/Content/Heading
@onready var message: Label = $Center/Panel/Content/Message
@onready var resume_button: Button = $Center/Panel/Content/Resume
@onready var restart_button: Button = $Center/Panel/Content/Restart

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)

func show_pause() -> void:
	heading.text = "Paused"
	message.text = "The battle is paused."
	resume_button.visible = true
	restart_button.visible = false
	visible = true

func show_result(is_victory: bool) -> void:
	heading.text = "Victory" if is_victory else "Defeat"
	message.text = (
		"The enemy has been defeated." if is_victory
		else "Your character has been defeated."
	)
	resume_button.visible = false
	restart_button.visible = true
	visible = true

func hide_overlay() -> void:
	visible = false

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()
