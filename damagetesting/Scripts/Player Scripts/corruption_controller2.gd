extends Node2D

@onready var player: Node2D = get_parent()
@onready var animation_controller = $"../AnimationController"

@export var MAX_CORRUPTION: int = 100
@export var move_speed_multipliers: Array = [1.0, 1.1, 1.2, 1.5, 0.0]
@export var attack_damage_multipliers: Array = [1.0, 1.6, 2.0, 2.6, 0.0]
# Index 0 => State 0
# Index 4 => State 4 (Max Corruption)

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
		player.corruption_damage_modf = attack_damage_multipliers[corruption_state]
		  # Make sure this uses `corruption_state`

func get_corruption_state() -> int:
	for i in corruption_thresholds.size() - 1:
		if current_corruption < corruption_thresholds[i + 1]:
			return i
	return corruption_thresholds.size() - 1
