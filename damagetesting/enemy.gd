extends CharacterBody2D

@export_category("Enemy Controller Settings")

# Attack Variables
@export_group("Attack Settings")
@export var ATTACK_DAMAGE: int = 10
@export var health: int = 100
@export var ATTACK_COOLDOWN: float = 2.0
@export var ATTACK_DURATION: float = 0.2
@export var KNOCKBACK_FORCE: float = 200
@export var TAKING_DAMAGE_TIME: float = 0.2
@export var ATTACK_WINDUP_TIME: float = 0.3
@export var ATTACK_SPEED: float = 400.0

var taking_damage_timer: float = 0.0
var is_taking_damage: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var attack_timer: float = 0.0
var player_direction: int = 0
var attack_dir: int = 0

# Physics Variables
@export_group("Physics")
@export var GRAVITY: float = 1200.0
@export var MOVE_SPEED: float = 80.0
@onready var move_dir: int = 0

# === Signals ===
signal deal_damage(damage: int, target: Node)

# === Nodes ===
@onready var player: Node = get_tree().get_first_node_in_group("Player")
@onready var LeftDownCast = $LeftDownCast
@onready var RightDownCast = $RightDownCast
@onready var LeftCast = $LeftCast
@onready var RightCast = $RightCast
@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	add_to_group("Enemy")
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	modulate = Color.RED

func _physics_process(delta: float) -> void:
	handle_timers(delta)
	handle_gravity(delta)
	hitbox_toggle()
	
	if not is_taking_damage and not is_attacking:
		handle_direction(delta)
	
	move_and_slide()

func handle_direction(_delta: float) -> void:
	if (LeftDownCast.is_colliding() and not RightDownCast.is_colliding()) or RightCast.is_colliding():
		move_dir = -1
	if (RightDownCast.is_colliding() and not LeftDownCast.is_colliding()) or LeftCast.is_colliding():
		move_dir = 1
	
	velocity.x = move_dir * MOVE_SPEED


func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func update_attack_timer(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta

func perform_attack() -> void:
	is_attacking = true
	modulate = Color.WHITE
#	attack_area.monitoring = true

	await get_tree().create_timer(ATTACK_DURATION).timeout

	is_attacking = false
	modulate = Color.RED
#	attack_area.monitoring = false
	attack_timer = ATTACK_COOLDOWN

func handle_timers(delta) -> void:
	if taking_damage_timer > 0:
		taking_damage_timer -= delta
	if taking_damage_timer <= 0:
		is_taking_damage = false

func _on_attack_area_body_entered(body: Node) -> void:
	if is_attacking and body.is_in_group("Player"):
		print("Enemy hit player!")
		emit_signal("deal_damage", ATTACK_DAMAGE, body)

func _on_player_deal_damage(damage: int, target: Node) -> void:
	if target != self:
		return
	apply_damage(damage)

#func start_attack():
	#is_attacking = true
	#can_attack = false
	#attack_dir = check_player_position()
	#velocity = Vector2.ZERO
#
	#await get_tree().create_timer(ATTACK_WINDUP_TIME).timeout
	#
	#if is_taking_damage or health <= 0:
		#is_attacking = false
		#return # Cancel if dead or hit
	#
	#velocity.x = attack_dir * ATTACK_SPEED
	#is_attacking = true
#
	#await get_tree().create_timer(ATTACK_DURATION).timeout
	#
	#velocity.x = 0
	#is_attacking = false
	#
	#await get_tree().create_timer(ATTACK_COOLDOWN_TIME).timeout
	#can_attack = true

func hitbox_toggle():
	if !is_attacking:
		attack_area.monitoring = false
	if is_attacking:
		attack_area.monitoring = true

func apply_damage(damage: int) -> void:
	taking_damage_timer = TAKING_DAMAGE_TIME
	is_taking_damage = true
	health -= damage
	print("Enemy took %d damage! Health is now: %d" % [damage, health])
	velocity.x = KNOCKBACK_FORCE * -check_player_position()
	velocity.y = KNOCKBACK_FORCE * 0.1
	if health <= 0:
		die()

func check_player_position() -> int:
	if player.global_position.x > self.global_position.x:
		return 1
	if player.global_position.x < self.global_position.x:
		return -1
	return 0

func die() -> void:
	print("Enemy died.")
	queue_free()
