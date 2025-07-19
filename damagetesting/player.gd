extends CharacterBody2D

signal deal_damage(damage: int, target: Node)

@export var damage_amount: int = 20
@export var health: int = 100
@export var attack_duration: float = 0.2

var is_attacking: bool = false
var default_color: Color = Color.WHITE
var attack_color: Color = Color.RED

@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	add_to_group("Player")
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	modulate = default_color

func _physics_process(delta: float) -> void:
	handle_input()

	# Follow mouse (temp logic)
	global_position = get_global_mouse_position()

func handle_input() -> void:
	if Input.is_action_just_pressed("ui_accept") and not is_attacking:
		start_attack()

func start_attack() -> void:
	is_attacking = true
	modulate = attack_color
	attack_area.monitoring = true

	await get_tree().create_timer(attack_duration).timeout

	is_attacking = false
	attack_area.monitoring = false
	modulate = default_color

func _on_attack_area_body_entered(body: Node) -> void:
	if is_attacking and body.is_in_group("Enemy"):
		print("Player hit enemy!")
		emit_signal("deal_damage", damage_amount, body)

func _on_enemy_deal_damage(damage: int, target: Node) -> void:
	if target != self:
		return

	health -= damage
	print("Player took ", damage, " damage! Health is now: ", health)

	if health <= 0:
		die()

func die() -> void:
	print("Player died.")
	queue_free()
