class_name CombatantDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export_range(1, 10000, 1) var max_hp: int = 100
@export_range(0, 9999, 1) var starting_guard: int = 0
@export_range(0, 99, 1) var starting_energy: int = 0
@export var skill_ids: Array[String] = []
@export var available_colors: Array[String] = ["red", "blue", "green", "yellow"]
@export var attack_modifiers: Dictionary = {}
@export var special_gem_loadout: SpecialGemLoadout
@export var portrait_path: String = ""
@export_group("Sprite Sheets")
## Horizontal strips; each frame is a square the size of the sheet height.
@export var idle_sheet: Texture2D
@export var hurt_sheet: Texture2D
@export var death_sheet: Texture2D
@export var attack_sheets: Array[Texture2D] = []
@export_range(1.0, 60.0, 1.0) var animation_fps: float = 10.0
@export_group("")
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_max_hp: int = 100) -> void:
	id = p_id
	name = p_name
	max_hp = p_max_hp
