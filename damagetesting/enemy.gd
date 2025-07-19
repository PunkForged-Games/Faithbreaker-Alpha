extends CharacterBody2D

signal deal_damage(damage: int, target: Node)

@export var damage_amount: int = 10
@export var health: int = 100
@export var attack_cooldown: float = 2.0
@export var attack_duration: float = 0.2

var is_attacking := false
var attack_timer := 0.0

@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	add_to_group("Enemy")
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	modulate = Color.RED

func _physics_process(delta: float) -> void:
	update_attack_timer(delta)
	if not is_attacking and attack_timer <= 0.0:
		await perform_attack()

func update_attack_timer(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta

func perform_attack() -> void:
	is_attacking = true
	modulate = Color.WHITE
	attack_area.monitoring = true

	await get_tree().create_timer(attack_duration).timeout

	is_attacking = false
	modulate = Color.RED
	attack_area.monitoring = false
	attack_timer = attack_cooldown

func _on_attack_area_body_entered(body: Node) -> void:
	if is_attacking and body.is_in_group("Player"):
		print("Enemy hit player!")
		emit_signal("deal_damage", damage_amount, body)

func _on_player_deal_damage(damage: int, target: Node) -> void:
	if target != self:
		return
	apply_damage(damage)

func apply_damage(damage: int) -> void:
	health -= damage
	print("Enemy took %d damage! Health is now: %d" % [damage, health])
	if health <= 0:
		die()

func die() -> void:
	print("Enemy died.")
	queue_free()
