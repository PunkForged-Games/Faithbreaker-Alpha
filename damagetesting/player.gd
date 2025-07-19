extends CharacterBody2D

@export_category("Player Controller Settings")
@export_group("Combat Settings")
@export var ATTACK_DMG: int = 20
@export var health: int = 100
@export var ATTACK_TIME: float = 0.2
var default_color: Color = Color.WHITE
var attack_color: Color = Color.RED
@export var ATTACK_COOLDOWN_TIME: float = 0.5
# Additional for taking damage from enemies
var is_invincible = false
var invincibility_timer: float = 0.0
@export var INVINCIBILITY_TIME: float = 0.5

# Movement Variables
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
# Motion Interpolation Variables
var previous_position: Vector2 = Vector2.ZERO
var current_position: Vector2 = Vector2.ZERO

# Wall Jump Settings
@export_group("Wall Jump Settings")
@export var WALL_JUMP_FORCE: Vector2 = Vector2(250, -300)
@export var WALL_SLIDE_SPEED: float = 60.0
@export var WALL_JUMP_LOCK_TIME: float = 0.2

# Dash Settings
@export_group("Dash Settings")
@export var DASH_SPEED: float = 500.0
@export var DASH_TIME: float = 0.15
@export var DASH_COOLDOWN: float = 0.3

# === STATE ===
#
# Jump State Controllers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0
var is_wall_sliding: bool = false
# Dash State Controllers
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
# Attack state controllers
var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_cooldown_timer: float = 0.0

# === Nodes ===
@onready var attack_area_L = $AttackAreaL
@onready var attack_area_R = $AttackAreaR
@onready var wall_check_left = $WallCheckL
@onready var wall_check_right = $WallCheckR
@onready var attack_r_debug_vfx = $AttackRightDebugText
@onready var attack_l_debug_vfx = $AttackLeftDebugText

# === Signals ===
signal deal_damage(damage: int, target: Node)


func _ready() -> void:
	add_to_group("Player")
	attack_area_L.monitoring = false
	attack_area_L.body_entered.connect(_on_attack_area_body_entered)
	attack_area_R.monitoring = false
	attack_area_R.body_entered.connect(_on_attack_area_body_entered)
	modulate = default_color

func _physics_process(delta: float) -> void:
	previous_position = current_position
	current_position = global_position
	var input_dir = get_input_vector()
	handle_timers(delta)
	if is_dashing:
		handle_dash(delta)
	else:
		handle_attack(delta)
		handle_gravity(delta)
		handle_wall_slide()
		handle_movement(input_dir, delta)
		handle_jumping()
		start_dash(input_dir)
		attack_time_control(delta)
		attack_cleanup()
	move_and_slide()
	update_state()

func _process(_delta: float) -> void:
	var interpolation_weight = Engine.get_physics_interpolation_fraction()
	var visual_position = previous_position.lerp(current_position, interpolation_weight)
	$Sprite2D.global_position = visual_position 

func get_input_vector() -> Vector2:
	var input = Vector2.ZERO
	input.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	facing_direction(input)
	return input.normalized()
	
func handle_gravity(delta: float) -> void:
	if not is_on_floor() and not is_wall_sliding:
		velocity.y += GRAVITY * delta

func fall_speed_limiter() -> void:
	if velocity.y < -MAX_FALL_SPEED:
		velocity.y = -MAX_FALL_SPEED

func facing_direction(direction: Vector2):
	if direction.x > 0 && $Sprite2D.flip_h == true:
		$Sprite2D.flip_h = false
	if direction.x < 0 && $Sprite2D.flip_h == false:
		$Sprite2D.flip_h = true

func handle_attack(delta: float) -> void:
	if Input.is_action_just_pressed("Attack_Left"):
		print("Attack Left!!!")
		start_attack(delta, "Left")
	if Input.is_action_just_pressed("Attack_Right"):
		print("Attack Right!!!")
		start_attack(delta, "Right")
	if Input.is_action_just_pressed("Attack_Up"):
		print("Attack Up!!!")
	if Input.is_action_just_pressed("Attack_Down"):
		print("Attack Down!!!")

func start_attack(_delta: float, attack_side: String) -> void:
	if  attack_cooldown_timer <= 0:
		is_attacking = true
		attack_timer = ATTACK_TIME
		attack_cooldown_timer = ATTACK_COOLDOWN_TIME
	if is_attacking:
		if attack_side == "Left":
			attack_l_debug_vfx.visible = true
			attack_area_L.monitoring = true
			print("Left Attack Area Active")
		elif attack_side == "Right":
			attack_r_debug_vfx.visible = true
			attack_area_R.monitoring = true
			print("Right attack area active")

func attack_time_control(delta: float) -> void:
	attack_timer -= delta
	if attack_timer <= 0:
		is_attacking = false

func attack_cleanup():
	if is_attacking == false:
		attack_l_debug_vfx.visible = false
		attack_r_debug_vfx.visible = false
		attack_area_L.monitoring = false
		attack_area_R.monitoring = false

# === WALL SLIDE ===
func handle_wall_slide() -> void:
	is_wall_sliding = false
	if is_touching_wall() and not is_on_floor() and velocity.y > 0:
		is_wall_sliding = true
		velocity.y = min(velocity.y, WALL_SLIDE_SPEED)

func handle_movement(input: Vector2, delta: float) -> void:
	if wall_jump_lock_timer > 0:
		return

	var target_speed = input.x * MAX_SPEED
	var accel = ACCEL if input.x != 0 else (FRICTION if is_on_floor() else AIR_DRAG)
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

# === JUMPING ===
func handle_jumping() -> void:
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	# Ground jump
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY 
		jump_buffer_timer = 0
		coyote_timer = 0

	# Wall jump
	elif jump_buffer_timer > 0 and is_touching_wall() and not is_on_floor():
		var wall_dir = 1 if wall_check_left.is_colliding() else -1
		print(str(wall_dir))
		velocity = Vector2(WALL_JUMP_FORCE.x * wall_dir, WALL_JUMP_FORCE.y)
		wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
		print("Wall Jump")
		jump_buffer_timer = 0

	# Early jump cut
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5
	if Input.is_action_just_released("ui_up") and velocity.y < 0:
		velocity.y *= 0.5

# === DASHING ===
func start_dash(input_vector: Vector2) -> void:
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		var dir = input_vector
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT if $Sprite2D.flip_h == false else Vector2.LEFT
		is_dashing = true
		dash_direction = dir.normalized()
		dash_timer = DASH_TIME
		dash_cooldown_timer = DASH_COOLDOWN
		velocity = dash_direction * DASH_SPEED

func handle_dash(delta: float) -> void:
	dash_timer -= delta
	if dash_timer <= 0:
		is_dashing = false
		return
	velocity = dash_direction * DASH_SPEED

# === TIMERS ===
func handle_timers(delta: float) -> void:
	if coyote_timer > 0:
		coyote_timer -= delta
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if wall_jump_lock_timer > 0:
		wall_jump_lock_timer -= delta
	if dash_cooldown_timer > 0 && is_on_floor():
		dash_cooldown_timer -= delta
	if attack_cooldown_timer > 0 && not is_attacking:
		attack_cooldown_timer -= delta
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false

# === GROUND / WALL DETECTION ===
func update_state() -> void:
	if is_on_floor() and not is_touching_wall():
		coyote_timer = COYOTE_TIME

func is_touching_wall() -> bool:
	return wall_check_left.is_colliding() or wall_check_right.is_colliding()

func _on_attack_area_body_entered(body: Node) -> void:
	if is_attacking and body.is_in_group("Enemy"):
		print("Player hit enemy!")
		emit_signal("deal_damage", ATTACK_DMG, body)

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
