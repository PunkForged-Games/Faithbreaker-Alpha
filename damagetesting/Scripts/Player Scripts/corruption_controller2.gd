extends Node2D

@onready var player: Node2D = get_parent()
@onready var animation_controller = $"../AnimationController"

@export var MAX_CORRUPTION: int = 100
@export var move_speed_multipliers: Array = [1.0, 1.1, 1.3, 1.5, 0.0] # --- Effects max player speed. ---
@export var move_control_modifiers: Array = [1.0, 1.2, 1.4, 1.6, 0.0] # --- Effects control acceleration rate of the player. ---
@export var jump_force_multipliers: Array = [1.0, 1.1, 1.2, 1.4, 0.0] # --- Effects jump power of the player. ---
@export var friction_force_multipliers: Array = [1.0, 1.2, 1.6, 1.8, 0.0] # --- Effects friction of player on the ground. ---
@export var air_drag_multipliers: Array = [1.0, 1.2, 1.4, 1.6, 0.0] # --- Effects air drag of player.
@export var attack_cd_multipliers: Array = [1.0, 0.9, 0.8, 0.5, 0.0] # --- Effects cooldown time of attack and dash.
@export var attack_damage_multipliers: Array = [1.0, 1.6, 2.0, 2.6, 0.0] # --- Effects damage output of player.

@onready var current_corruption: int = 0

# Define corruption thresholds
var corruption_thresholds := [0, 25, 50, 75, MAX_CORRUPTION]
var corruption_state: int = 0

func _ready() -> void:
	update_corruption_state()

func _physics_process(_delta: float) -> void:
	#print(corruption_state)
	update_corruption_state()

func take_corruption_damage(corruption_amount):
	current_corruption += corruption_amount

func update_corruption_state() -> void:
	var new_state := get_corruption_state()
	if new_state != corruption_state:
		corruption_state = new_state
		#print("Corruption state changed to:", corruption_state)
		player.corruption_movement_modf = move_speed_multipliers[corruption_state]
		player.corruption_control_modf = move_control_modifiers[corruption_state]
		player.corruption_jump_modf = jump_force_multipliers[corruption_state]
		player.corruption_friction_modf = friction_force_multipliers[corruption_state]
		player.corruption_drag_modf = air_drag_multipliers[corruption_state]
		player.corruption_atkCD_modf = attack_cd_multipliers[corruption_state]
		player.corruption_damage_modf = attack_damage_multipliers[corruption_state]

func get_corruption_state() -> int:
	for i in corruption_thresholds.size() - 1:
		if current_corruption < corruption_thresholds[i + 1]:
			return i
	return corruption_thresholds.size() - 1
