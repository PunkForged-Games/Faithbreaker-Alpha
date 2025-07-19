extends Node2D

@onready var player = $Player

func _ready():
	# Connect already existing enemies
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		_connect_enemy_signals(enemy)

	# Listen for dynamically added enemies
	get_tree().connect("node_added", Callable(self, "_on_node_added"))

func _on_node_added(node: Node) -> void:
	if node.is_in_group("Enemy"):
		_connect_enemy_signals(node)

func _connect_enemy_signals(enemy: Node) -> void:
	if not player.deal_damage.is_connected(Callable(enemy, "_on_player_deal_damage")):
		player.deal_damage.connect(Callable(enemy, "_on_player_deal_damage"))

	if not enemy.deal_damage.is_connected(Callable(player, "_on_enemy_deal_damage")):
		enemy.deal_damage.connect(Callable(player, "_on_enemy_deal_damage"))
