extends Line2D

@export_category("Trail")
@export var length: int = 40

@onready var parent: Node2D = get_parent()
var offset: Vector2 = Vector2.ZERO

func _ready():
	offset = position
	top_level = false

func _physics_process(_delta: float) -> void:
	global_position = Vector2.ZERO
	
	var point: = parent.global_position + offset
	add_point(point, 0)
	
	if get_point_count() > length:
		remove_point(get_point_count() - 1)
