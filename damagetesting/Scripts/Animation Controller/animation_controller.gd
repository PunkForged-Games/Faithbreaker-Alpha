extends Node2D

@onready var player_sprite = $"../AnimatedSprite2D"
@onready var corruption_controller = $"../CorruptionController"
@onready var corruption_state: int

@onready var RightAttack = $"../RightAttack"
@onready var initial_position = RightAttack.position
@onready var player = $"../"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	RightAttack.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	movement_animation_controller()
	
func update_corruption_state():
	print("success on update")

func side_attack_animation(facing):
	if facing > 0:
		RightAttack.position = initial_position
		RightAttack.flip_h = false
		RightAttack.visible = true
		RightAttack.play("default")
	elif facing <0:
		RightAttack.position = Vector2(-initial_position.x, initial_position.y)
		RightAttack.flip_h = true
		RightAttack.visible = true
		RightAttack.play("default")

func movement_animation_controller():
	if player.is_on_floor():
		if player.velocity.x != 0:
			player_sprite.flip_h = player.velocity.x < 0
			player_sprite.play("Run1")
		else:
			player_sprite.play("Idle1")
		return

	if not player.is_wall_sliding:
		player_sprite.flip_h = player.velocity.x < 0

		if player.velocity.x != 0:
			player_sprite.play("FallSide1" if player.velocity.y >= 0 else "JumpSide1")
		else:
			player_sprite.play("FallNull1" if player.velocity.y >= 0 else "JumpNull1")

			

func _on_right_attack_animation_finished() -> void:
	RightAttack.visible = false
	RightAttack.stop()
	pass # Replace with function body.
