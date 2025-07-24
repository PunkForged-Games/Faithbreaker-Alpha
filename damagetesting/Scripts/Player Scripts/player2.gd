extends CharacterBody2D

# === EXPORTS ===
@export_category("Player Controller Settings")

@export_group("Combat Settings")
@export var ATTACK_DMG: float = 35.0
@export var MAX_HEALTH: float = 100
@export var health: float = 100.0
@export var ATTACK_TIME: float = 0.2
@export var ATTACK_COOLDOWN_TIME: float = 0.5
@export var INVINCIBILITY_TIME: float = 0.2
@export var KNOCKBACK_FORCE: float = 200.0
@export var IS_DAMAGED_DURATION: float = 0.2

@export_group("Movement Settings")
@export var GRAVITY: float = 1200.0
@export var MAX_SPEED: float = 200.0
@export var ACCEL: float = 800.0
@export var FRICTION: float = 700.0
@export var AIR_DRAG: float = 300.0
@export var JUMP_VELOCITY: float = -350.0
@export var SUPER_JUMP_VELOCITY: float = -1000.0
@export var COYOTE_TIME: float = 0.1
@export var JUMP_BUFFER_TIME: float = 0.1
@export var MAX_FALL_SPEED: float = 400.0

@export_group("Wall Jump Settings")
@export var WALL_JUMP_FORCE: Vector2 = Vector2(250, -300)
@export var WALL_SLIDE_SPEED: float = 60.0
@export var WALL_JUMP_LOCK_TIME: float = 0.2

@export_group("Dash Settings")
@export var DASH_SPEED: float = 500.0
@export var DASH_TIME: float = 0.15
@export var DASH_COOLDOWN: float = 0.3

# === SIGNALS ===
signal deal_damage(damage: int, target: Node)

# === NODES ===
@onready var attack_area_L = $AttackAreaL
@onready var attack_area_R = $AttackAreaR
@onready var wall_check_left = $WallCheckL
@onready var wall_check_right = $WallCheckR
@onready var wall_jump_down_cast = $WallJumpDownCast
@onready var wall_jump_up_cast = $WallJumpUpCast
@onready var sprite = $Sprite2D
@onready var animated_sprite = $AnimatedSprite2D

@onready var animation_controller = $AnimationController
@onready var corruption_controller = $CorruptionController

@onready var camera_controller = $"../Camera2D"

# === STATE VARIABLES ===
var previous_position: Vector2 = Vector2.ZERO
var current_position: Vector2 = Vector2.ZERO

# Timers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var attack_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var invincibility_timer: float = 0.0
var is_damaged_timer: float = 0.0

# States
var can_wall_slide: bool = true
var is_wall_sliding: bool = false
var is_dashing: bool = false
var is_attacking: bool = false
var is_invincible: bool = false
var is_damaged: bool = false

# === Corruption Related Variables ===
@onready var corruption_movement_modf: float
@onready var corruption_control_modf: float
@onready var corruption_jump_modf: float
@onready var corruption_friction_modf: float
@onready var corruption_drag_modf: float
@onready var corruption_atkCD_modf: float
@onready var corruption_damage_modf: float


var dash_direction: Vector2 = Vector2.ZERO

# Developer / Debug
@onready var is_developer: bool = true
@onready var respawn_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("Player")
	respawn_pos = global_position
	attack_area_L.monitoring = false
	attack_area_L.body_entered.connect(_on_attack_area_body_entered)
	attack_area_R.monitoring = false
	attack_area_R.body_entered.connect(_on_attack_area_body_entered)
	modulate = Color.WHITE
	init_corruption()

func init_corruption():
	corruption_movement_modf = 1.0
	corruption_control_modf = 1.0
	corruption_jump_modf = 1.0
	corruption_friction_modf = 1.0
	corruption_drag_modf = 1.0
	corruption_atkCD_modf = 1.0
	corruption_damage_modf = 1.0

func _physics_process(delta: float) -> void:
	previous_position = current_position
	current_position = global_position
	handle_timers(delta)
	if is_damaged:
		_process_knockback(delta)
		return
	if is_dashing:
		_process_dash(delta)
	else:
		_process_input_and_movement(delta)
	move_and_slide()
	update_state()

func _process(_delta: float) -> void:
	_interpolate_sprite_position()
	_update_invincibility_visual()

func _process_knockback(delta: float) -> void:
	attack_time_control(delta)
	move_and_slide()
	# Debug
	#print("Knockback active. Velocity:", velocity)

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	if dash_timer <= 0:
		is_dashing = false
		return
	velocity = dash_direction * DASH_SPEED * corruption_movement_modf

func _process_input_and_movement(delta: float) -> void:
	handle_attack_input()
	handle_gravity(delta)
	handle_wall_slide()
	handle_movement(get_input_vector(), delta)
	handle_jumping()
	start_dash(get_input_vector())
	attack_time_control(delta)
	attack_cleanup()

func _interpolate_sprite_position() -> void:
	var weight = Engine.get_physics_interpolation_fraction()
	var visual_pos = previous_position.lerp(current_position, weight)
	animated_sprite.global_position = visual_pos + Vector2(0, 9)

func _update_invincibility_visual() -> void:
	modulate.a = 0.5 if is_invincible else 1.0

# --- Input & Movement ---

func get_input_vector() -> Vector2:
	var input_vec = Vector2.ZERO
	input_vec.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vec.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	_update_facing_direction(input_vec)
	return input_vec.normalized()

func _update_facing_direction(dir: Vector2) -> void:
	if dir.x > 0 and sprite.flip_h:
		sprite.flip_h = false
		animated_sprite.flip_h = false
	elif dir.x < 0 and not sprite.flip_h:
		sprite.flip_h = true
		animated_sprite.flip_h = true

func handle_movement(input: Vector2, delta: float) -> void:
	# Only block air control during wall jump lock
	#if wall_jump_lock_timer > 0 and not is_on_floor() and !wall_jump_down_cast.is_colliding() and !wall_jump_up_cast.is_colliding():
		#
		#return
	var target_speed = input.x * MAX_SPEED 
	var accel = ACCEL * corruption_movement_modf if input.x != 0 else (FRICTION * corruption_friction_modf if is_on_floor() else AIR_DRAG * corruption_drag_modf)
	velocity.x = move_toward(velocity.x, target_speed * corruption_movement_modf, accel * delta)
	if velocity.y > MAX_FALL_SPEED:
		velocity.y = MAX_FALL_SPEED
	#print(str(corruption_movement_modf))

func handle_gravity(delta: float) -> void:
	if not is_on_floor() and not is_wall_sliding:
		velocity.y += GRAVITY * corruption_jump_modf * delta

func handle_wall_slide() -> void:
	var touching_wall = is_touching_wall()
	var falling = velocity.y > 0
	var in_air = not is_on_floor()

	# === Reset wall slide state on floor ===
	if is_on_floor():
		is_wall_sliding = false
		can_wall_slide = true
		wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
		return

	# === If already sliding ===
	if is_wall_sliding:
		if wall_jump_lock_timer > 0 and touching_wall and in_air and falling:
			wall_jump_lock_timer -= get_physics_process_delta_time()
			velocity.y = min(velocity.y, WALL_SLIDE_SPEED)
		else:
			is_wall_sliding = false
			can_wall_slide = false
		return

	# === Try to enter wall slide ===
	if touching_wall and in_air and falling and can_wall_slide and wall_jump_lock_timer <= 0:
		is_wall_sliding = true
		wall_jump_lock_timer = WALL_JUMP_LOCK_TIME

func handle_jumping() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = JUMP_VELOCITY * corruption_jump_modf
			jump_buffer_timer = 0
			coyote_timer = 0
		elif is_touching_wall() and not is_on_floor() and !wall_jump_down_cast.is_colliding():
			var wall_dir = 1 if wall_check_left.is_colliding() else -1
			velocity = Vector2(WALL_JUMP_FORCE.x * corruption_jump_modf * wall_dir, WALL_JUMP_FORCE.y * corruption_jump_modf)
			wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
			jump_buffer_timer = 0

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

# --- Dash ---

func start_dash(input_vec: Vector2) -> void:
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		var dir = input_vec
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT
		is_dashing = true
		dash_direction = dir.normalized()
		dash_timer = DASH_TIME
		dash_cooldown_timer = DASH_COOLDOWN * corruption_atkCD_modf
		velocity = dash_direction * DASH_SPEED

# --- Attack ---
func handle_attack_input() -> void:
	if Input.is_action_just_pressed("Attack_Left"):
		start_attack("Left")
	elif Input.is_action_just_pressed("Attack_Right"):
		start_attack("Right")
	elif Input.is_action_just_pressed("Attack_Up"):
		pass # Add up attack if needed
	elif Input.is_action_just_pressed("Attack_Down"):
		pass # Add down attack if needed

func start_attack(side: String) -> void:
	if attack_cooldown_timer > 0:
		return
	is_attacking = true
	attack_timer = ATTACK_TIME
	attack_cooldown_timer = ATTACK_COOLDOWN_TIME * corruption_atkCD_modf
	if side == "Left":
		attack_area_L.monitoring = true
		animation_controller.side_attack_animation(-1)
	elif side == "Right":
		attack_area_R.monitoring = true
		animation_controller.side_attack_animation(1)

func attack_time_control(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0:
		is_attacking = false
	if is_damaged_timer <= 0:
		is_damaged = false

func attack_cleanup() -> void:
	if not is_attacking:
		attack_area_L.monitoring = false
		attack_area_R.monitoring = false

# --- Utility ---
func is_touching_wall() -> bool:
	return wall_check_left.is_colliding() or wall_check_right.is_colliding()

func update_state() -> void:
	if is_on_floor() and not is_touching_wall():
		coyote_timer = COYOTE_TIME
	if is_damaged:
		is_invincible = true

func handle_timers(delta: float) -> void:
	if coyote_timer > 0:
		coyote_timer -= delta
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if wall_jump_lock_timer > 0:
		wall_jump_lock_timer -= delta
	if dash_cooldown_timer > 0 and is_on_floor():
		dash_cooldown_timer -= delta
	if attack_cooldown_timer > 0 and not is_attacking:
		attack_cooldown_timer -= delta
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
	if is_damaged_timer > 0:
		is_damaged_timer -= delta

# --- Signals ---
func _on_attack_area_body_entered(body: Node) -> void:
	if is_attacking and body.is_in_group("Enemy"):
		emit_signal("deal_damage", ATTACK_DMG * corruption_damage_modf, body)
		print(ATTACK_DMG * corruption_damage_modf)

func _on_enemy_deal_damage(damage: int, corruption_damage: int, target: Node2D, direction: int) -> void:
	if target != self:
		return
	if is_invincible:
		return
	health -= damage
	corruption_controller.take_corruption_damage(corruption_damage)
	print("Player took ", damage, " damage! Health is now: ", health)
	_apply_knockback(direction)
	if health <= 0:
		die()

func _apply_knockback(direction: int) -> void:
	velocity.x = direction * KNOCKBACK_FORCE
	velocity.y = -KNOCKBACK_FORCE * 0.1
	is_damaged = true
	is_damaged_timer = IS_DAMAGED_DURATION
	is_invincible = true
	invincibility_timer = INVINCIBILITY_TIME
	camera_controller.shake_intensity = 15
	
	# Here down: add signal function to handle health + corruption pickups for use in-game.

func die() -> void:
	print("Player died.")
	corruption_controller.current_corruption = 0
	if is_developer:
		global_position = respawn_pos
		health = 100
	else:
		queue_free()
