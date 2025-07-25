extends Node2D

@onready var heal_amount: int
@onready var player: CharacterBody2D = $"../Player"

func _ready() -> void:
	print(str(player))
	
func heal_player():
	if player.MAX_HEALTH - player.health >= heal_amount:
		player.health += heal_amount
	else:
		return




# Signals for player pickups to follow below.
