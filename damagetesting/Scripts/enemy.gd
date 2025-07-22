extends CharacterBody2D

@export_category("Enemy Controller Settings")

# === Attack Variables ===
@export_group("Attack Settings")
@export var ATTACK_DAMAGE: int = 15
@export var health: int = 100
@export var ATTACK_COOLDOWN: float = 2.0
@export var ATTACK_DURATION: float = 0.2
@export var ATTACK_WINDUP_TIME: float = 0.3
@export var ATTACK_SPEED: float = 400.0
@export var KNOCKBACK_FORCE: float = 200.0
@export var TAKING_DAMAGE_TIME: float = 0.2
@export var CORRUPTION_DAMAGE: int = 10
var has_hit_during_attack = false

# === Physics Variables ===
@export_group("Physics")
@export var GRAVITY: float = 1200.0
@export var MOVE_SPEED: float = 80.0

# === Runtime Variables ===
var attack_timer: float = 0.0
var taking_damage_timer: float = 0.0
var is_taking_damage: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var move_dir: int = 0
var charge_direction: Vector2 = Vector2.ZERO

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
	move_dir = [-1, 1].pick_random()
	add_to_group("Enemy")
	attack_area.monitoring = false
	if attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.disconnect(_on_attack_area_body_entered)
	
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	modulate = Color.RED

func _physics_process(delta: float) -> void:
	handle_timers(delta)
	handle_gravity(delta)
	hitbox_toggle()

	if not is_attacking and not is_taking_damage:
		handle_direction(delta)

	move_and_slide()

	# Detect and initiate attack if ready
	if not is_attacking and can_attack and is_player_in_range():
		start_attack()

func handle_direction(_delta: float) -> void:
	if (LeftDownCast.is_colliding() and not RightDownCast.is_colliding()) or RightCast.is_colliding():
		move_dir = -1
	elif (RightDownCast.is_colliding() and not LeftDownCast.is_colliding()) or LeftCast.is_colliding():
		move_dir = 1

	velocity.x = move_dir * MOVE_SPEED

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func handle_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
	if attack_timer <= 0.0:
		can_attack = true
	if taking_damage_timer > 0.0:
		taking_damage_timer -= delta
	if taking_damage_timer <= 0.0:
		is_taking_damage = false

func hitbox_toggle() -> void:
	attack_area.monitoring = is_attacking

func is_player_in_range() -> bool:
	return player != null and global_position.distance_to(player.global_position) < 80.0

func start_attack() -> void:
	has_hit_during_attack = false
	can_attack = false
	is_attacking = true
	velocity = Vector2.ZERO
	modulate = Color.YELLOW

	var target_pos: Vector2 = player.global_position
	charge_direction = (target_pos - global_position).normalized()

	# Begin windup phase
	await get_tree().create_timer(ATTACK_WINDUP_TIME).timeout

	# Abort if hit or dead during windup
	if is_taking_damage or health <= 0:
		end_attack()
		return

	modulate = Color.WHITE
	velocity = charge_direction * ATTACK_SPEED

	await get_tree().create_timer(ATTACK_DURATION).timeout

	end_attack()

func end_attack() -> void:
	is_attacking = false
	modulate = Color.RED
	velocity.x = 0
	attack_timer = ATTACK_COOLDOWN
	can_attack = false

func _on_attack_area_body_entered(body: Node) -> void:
	if not is_attacking or has_hit_during_attack:
		return
	if body.is_in_group("Player"):
		var direction = check_player_position()
		print("Enemy hit player!")
		emit_signal("deal_damage", ATTACK_DAMAGE, CORRUPTION_DAMAGE, body, direction)
		has_hit_during_attack = true

func apply_damage(damage: int) -> void:
	taking_damage_timer = TAKING_DAMAGE_TIME
	is_taking_damage = true
	health -= damage
	print("Enemy took %d damage! Health is now: %d" % [damage, health])
	velocity.x = KNOCKBACK_FORCE * -check_player_position()
	velocity.y = KNOCKBACK_FORCE * 0.1
	if health <= 0:
		die()

func _on_player_deal_damage(damage: int, target: Node) -> void:
	if target == self:
		apply_damage(damage)

func check_player_position() -> int:
	player = get_tree().get_first_node_in_group("Player")
	if player.global_position.x > self.global_position.x:
			return 1
	elif player.global_position.x < self.global_position.x:
			return -1
	return [-1, 1].pick_random()

func die() -> void:
	print("Enemy died.")
	queue_free()
