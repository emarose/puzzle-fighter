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
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_max_hp: int = 100) -> void:
	id = p_id
	name = p_name
	max_hp = p_max_hp
