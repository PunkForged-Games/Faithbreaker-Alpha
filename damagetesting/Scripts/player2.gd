extends CharacterBody2D

# === EXPORTS ===
@export_category("Player Controller Settings")

@export_group("Combat Settings")
@export var ATTACK_DMG: int = 20
@export var health: int = 100
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
@export var MAX_FALL_SPEED: float = 2

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
@onready var attack_r_debug_vfx = $AttackRightDebugText
@onready var attack_l_debug_vfx = $AttackLeftDebugText
@onready var sprite = $Sprite2D
@onready var animated_sprite = $AnimatedSprite2D

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
var is_wall_sliding: bool = false
var is_dashing: bool = false
var is_attacking: bool = false
var is_invincible: bool = false
var is_damaged: bool = false

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
	velocity = dash_direction * DASH_SPEED

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
	sprite.global_position = visual_pos
	animated_sprite.global_position = visual_pos
	animated_sprite.global_position.y = animated_sprite.global_position.y + 8
	if velocity.y < 1 && velocity.x < 1:
		animated_sprite.global_position = current_position
		animated_sprite.global_position.y = animated_sprite.global_position.y + 8

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
	if wall_jump_lock_timer > 0:
		return

	var target_speed = input.x * MAX_SPEED
	var accel = ACCEL if input.x != 0 else (FRICTION if is_on_floor() else AIR_DRAG)
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

func handle_gravity(delta: float) -> void:
	if not is_on_floor() and not is_wall_sliding:
		velocity.y += GRAVITY * delta

func handle_wall_slide() -> void:
	is_wall_sliding = false
	if is_touching_wall() and not is_on_floor() and velocity.y > 0:
		is_wall_sliding = true
		velocity.y = min(velocity.y, WALL_SLIDE_SPEED)

func handle_jumping() -> void:
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = JUMP_VELOCITY
			jump_buffer_timer = 0
			coyote_timer = 0
		elif is_touching_wall() and not is_on_floor():
			var wall_dir = 1 if wall_check_left.is_colliding() else -1
			velocity = Vector2(WALL_JUMP_FORCE.x * wall_dir, WALL_JUMP_FORCE.y)
			wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
			jump_buffer_timer = 0

	if (Input.is_action_just_released("jump") or Input.is_action_just_released("ui_up")) and velocity.y < 0:
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
		dash_cooldown_timer = DASH_COOLDOWN
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
	attack_cooldown_timer = ATTACK_COOLDOWN_TIME

	if side == "Left":
		attack_l_debug_vfx.visible = true
		attack_area_L.monitoring = true
	elif side == "Right":
		attack_r_debug_vfx.visible = true
		attack_area_R.monitoring = true

func attack_time_control(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0:
		is_attacking = false
	if is_damaged_timer <= 0:
		is_damaged = false

func attack_cleanup() -> void:
	if not is_attacking:
		attack_l_debug_vfx.visible = false
		attack_r_debug_vfx.visible = false
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
		emit_signal("deal_damage", ATTACK_DMG, body)

func _on_enemy_deal_damage(damage: int, target: Node2D, direction: int) -> void:
	if target != self:
		return
	if is_invincible:
		return

	health -= damage
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

func die() -> void:
	print("Player died.")
	if is_developer:
		global_position = respawn_pos
		health = 100
	else:
		queue_free()
