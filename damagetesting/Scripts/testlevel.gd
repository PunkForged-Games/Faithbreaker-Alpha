extends Node2D

@onready var player = $Player
@onready var corruption_controller = $Player/CorruptionController
@onready var corruption_bar = $UILayer/CanvasLayer/MarginContainer2/CorruptionBar
@onready var health_bar = $UILayer/CanvasLayer/MarginContainer/HealthBar

@onready var corruption_bar_color: Dictionary = {
	0: Color.WEB_GREEN,
	1: Color.YELLOW,
	2: Color.ORANGE,
	3: Color.RED,
	4: Color.DARK_RED
}


@onready var fps_counter = $UILayer/CanvasLayer/FPSCounter

func _ready():
	# Connect already existing enemies
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		_connect_enemy_signals(enemy)

	# Listen for dynamically added enemies
	get_tree().connect("node_added", Callable(self, "_on_node_added"))

func _process(_delta):
	health_bar.value = player.health
	corruption_bar.value = corruption_controller.current_corruption
	corruption_bar.tint_progress = corruption_bar_color[corruption_controller.corruption_state]
	# Change color based on health %
	var percent = float(player.health) / float(health_bar.max_value)
	if percent < 0.25:
		health_bar.add_theme_color_override("fg", Color.RED)
	elif percent < 0.5:
		health_bar.add_theme_color_override("fg", Color.ORANGE)
	else:
		health_bar.add_theme_color_override("fg", Color.GREEN)
	#print(health_bar.value)
	var framerate = Engine.get_frames_per_second()
	fps_counter.text = "FPS: " + str(framerate) + " " + "X.Velocity(" + str(roundi(player.velocity.x)) + ")" + " " + "Y.Velocity(" + str(roundi(player.velocity.y)) + ")"

func _on_node_added(node: Node) -> void:
	if node.is_in_group("Enemy"):
		_connect_enemy_signals(node)

func _connect_enemy_signals(enemy: Node) -> void:
	if not player.deal_damage.is_connected(Callable(enemy, "_on_player_deal_damage")):
		player.deal_damage.connect(Callable(enemy, "_on_player_deal_damage"))

	if not enemy.deal_damage.is_connected(Callable(player, "_on_enemy_deal_damage")):
		enemy.deal_damage.connect(Callable(player, "_on_enemy_deal_damage"))
