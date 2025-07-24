extends Node2D

@onready var player: Node2D = get_parent()
@onready var animation_controller = $"../AnimationController"
@onready var MAX_CORRUPTION: int = 100
@onready var FIRST_STATE = range(0, 25)
@onready var SECOND_STATE = range(25, 50)
@onready var THIRD_STATE = range(50, 75)
@onready var FOURTH_STATE = range(75, 100)

@export var move_speed_multipliers: Array = [1.0, 1.4, 1.8, 2.2]

@onready var current_corruption: int = 0

var corruption_state: int
var current_state: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	corruption_state = 1
	current_state = corruption_state
	animation_controller.update_corruption_state()
	print(FIRST_STATE, SECOND_STATE, THIRD_STATE)
	handle_corruption_states()

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		current_corruption -= 1
	if Input.is_action_pressed("ui_right"):
		current_corruption += 1
	if current_corruption > MAX_CORRUPTION:
		current_corruption = MAX_CORRUPTION
	if current_corruption < 0:
		current_corruption = 0
	handle_corruption_states()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func update_state(current, new):
	corruption_state = new
	current_state = new
	print("updated")
	print("Current state is - ", current_state)

func check_needs_update(current, state_id):
	if current_state != state_id:
		update_state(current, state_id)

func handle_corruption_states():
	if current_corruption in FIRST_STATE:
		check_needs_update(current_state, 0)
	if current_corruption in SECOND_STATE:
		check_needs_update(current_state, 1)
	if current_corruption in THIRD_STATE:
		check_needs_update(current_state, 2)
	if current_corruption in FOURTH_STATE:
		check_needs_update(current_state, 3)
	if current_corruption >= MAX_CORRUPTION:
		check_needs_update(current_state, 4)
