extends Node2D

@onready var player_sprite = $"../AnimatedSprite2D"
@onready var corruption_controller = $"../CorruptionController"
@onready var corruption_state: int

@onready var RightAttack = $"../RightAttack"
@onready var initial_position = RightAttack.position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	RightAttack.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	return
	
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

func _on_right_attack_animation_finished() -> void:
	RightAttack.visible = false
	RightAttack.stop()
	pass # Replace with function body.
