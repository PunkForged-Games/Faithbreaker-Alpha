extends Camera2D

@export_node_path("Node2D") var player_path: NodePath
@export var follow_speed := 5.0

@export var deadzone_size := Vector2(32, 24)
@export var directional_offset_strength := 48.0
@export var direction_lerp_speed := 8.0

@export var shake_intensity := 0.0
@export var shake_decay := 5.0

# Internal variables
var _player: Node2D
var _velocity := Vector2.ZERO
var _current_offset := Vector2.ZERO
var _last_player_position := Vector2.ZERO
var _shake_offset := Vector2.ZERO

# Zoom variables
var _zoom_target := Vector2.ONE
var _zoom_timer := 0.0
const ZOOM_DELAY := 0.3
const ZOOM_LERP_SPEED := 4.0

func _ready():
	_player = get_node_or_null(player_path)
	if not _player:
		push_warning("Camera2D: Player not found. Assign a valid player_path.")
	make_current()

func _process(delta):
	if not _player:
		return

	_update_player_velocity(delta)
	_update_camera_position(delta)
	_apply_camera_shake(delta)
	_update_follow_speed()
	_update_zoom(delta)

# --- Player Directional Offset ---
func _update_player_velocity(delta):
	var player_pos = _player.global_position
	var move_delta = player_pos - _last_player_position
	_last_player_position = player_pos

	if move_delta.length() > 0.1:
		_velocity = lerp(_velocity, move_delta.normalized(), delta * direction_lerp_speed)
	else:
		_velocity = lerp(_velocity, Vector2.ZERO, delta * direction_lerp_speed)

# --- Camera Position ---
func _update_camera_position(delta):
	var player_pos = _player.global_position
	var directional_offset = Vector2(_velocity.x, 0) * directional_offset_strength
	_current_offset = lerp(_current_offset, directional_offset, delta * direction_lerp_speed)

	var target_pos = player_pos + _current_offset
	var camera_offset = target_pos - global_position
	var deadzone_half = deadzone_size * 0.5

	if abs(camera_offset.x) > deadzone_half.x:
		global_position.x += (camera_offset.x - sign(camera_offset.x) * deadzone_half.x) * delta * follow_speed
	if abs(camera_offset.y) > deadzone_half.y:
		global_position.y += (camera_offset.y - sign(camera_offset.y) * deadzone_half.y) * delta * follow_speed

	global_position += _shake_offset

# --- Camera Shake ---
func _apply_camera_shake(delta):
	if shake_intensity > 0.01:
		_shake_offset = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * shake_intensity
		shake_intensity = lerp(shake_intensity, 0.0, delta * shake_decay)
	else:
		_shake_offset = Vector2.ZERO

# --- Follow Speed Boost ---
func _update_follow_speed():
	var vy = _player.velocity.y
	if vy > 800:
		follow_speed = 20.0
	elif vy > 600:
		follow_speed = 15.0
	elif vy > 400:
		follow_speed = 10.0
	else:
		follow_speed = 5.0

# --- Dynamic Zoom Based on Player Speed ---
#func _update_zoom(delta):
	#var speed = _player.velocity.length()
	#print(str(speed))
	#var desired_zoom = clamp(1.0 - (speed * 0.002), 0.75, 1.0)
	#print(str(desired_zoom))
#
	## If the zoom target changes significantly, reset delay timer
	#if abs(_zoom_target.x - desired_zoom) > 0.2:
		#_zoom_target = Vector2(desired_zoom, desired_zoom)
		#_zoom_timer = ZOOM_DELAY
	#else:
		## Countdown the delay timer
		#_zoom_timer = max(_zoom_timer - delta, 0.0)
#
	## Only start interpolating when delay is over
	#if _zoom_timer <= 0.01:
		#zoom = zoom.lerp(_zoom_target, ZOOM_LERP_SPEED * delta)
		
func _update_zoom(delta):
	var speed = _player.velocity.length()
	var desired_zoom = clamp(1.0 - (speed * 0.002), 0.75, 1.0)

	# If the zoom target changes significantly, reset delay timer
	if abs(_zoom_target.x - desired_zoom) > 0.2:
		_zoom_target = Vector2(desired_zoom, desired_zoom)
		_zoom_timer = ZOOM_DELAY
	else:
		# Countdown the delay timer
		_zoom_timer = max(_zoom_timer - delta, 0.0)

	# Only start interpolating when delay is over
	if _zoom_timer <= 0.01:
		# Snap to target if nearly there, to avoid micro-jitter
		if abs(zoom.x - _zoom_target.x) < 0.02:
			zoom = _zoom_target
		else:
			zoom = zoom.lerp(_zoom_target, ZOOM_LERP_SPEED * delta)
