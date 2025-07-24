extends Camera2D

@export_node_path("Node2D") var player_path: NodePath
@export var follow_speed := 5.0

@export var deadzone_size := Vector2(32, 24)
@export var directional_offset_strength := 48.0
@export var direction_lerp_speed := 8.0

@export var shake_intensity := 0.0
@export var shake_decay := 5.0
var _shake_offset := Vector2.ZERO

var _player: Node2D
var _velocity := Vector2.ZERO
var _current_offset := Vector2.ZERO
var _last_player_position := Vector2.ZERO

func _ready():
	_player = get_node_or_null(player_path)
	if not _player:
		push_warning("Camera2D: Player not found. Assign a valid player_path.")
	make_current()

func _process(delta):
	if not _player:
		return
	var player_pos = _player.global_position
	var move_delta = player_pos - _last_player_position
	_last_player_position = player_pos
	# Only update velocity when player actually moves (not from camera motion)
	if move_delta.length() > 0.1:
		_velocity = lerp(_velocity, move_delta.normalized(), delta * direction_lerp_speed)
	else:
		_velocity = lerp(_velocity, Vector2.ZERO, delta * direction_lerp_speed)
	# Optional: Only apply directional offset on X
	var directional_offset = Vector2(_velocity.x, 0) * directional_offset_strength
	_current_offset = lerp(_current_offset, directional_offset, delta * direction_lerp_speed)
	# Final target with offset
	var target_pos = player_pos + _current_offset
	var camera_offset = target_pos - global_position
	# Deadzone clamp
	var deadzone_half = deadzone_size * 0.5
	if abs(camera_offset.x) > deadzone_half.x:
		global_position.x += (camera_offset.x - sign(camera_offset.x) * deadzone_half.x) * delta * follow_speed
	if abs(camera_offset.y) > deadzone_half.y:
		global_position.y += (camera_offset.y - sign(camera_offset.y) * deadzone_half.y) * delta * follow_speed
	# Shake
	if shake_intensity > 0.01:
		_shake_offset = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * shake_intensity
		shake_intensity = lerp(shake_intensity, 0.0, delta * shake_decay)
	else:
		_shake_offset = Vector2.ZERO
	if _player.velocity.y > 800:
		follow_speed = 20.0
	if _player.velocity.y < 800 && _player.velocity.y > 600:
		follow_speed = 15.0
	if _player.velocity.y < 600 && _player.velocity.y > 400:
		follow_speed = 10
	else:
		follow_speed = 5.0
	global_position += _shake_offset
