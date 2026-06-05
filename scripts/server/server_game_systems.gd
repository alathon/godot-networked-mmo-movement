extends Node

@onready var ticker: Ticker = %Ticker
@onready var player_spawner: Node = %PlayerSpawner
@onready var player_input_handler: Node = %PlayerInputHandler

var _tick_context: Dictionary[int, Dictionary] = {}

func _ready() -> void:
	ticker.tick.connect(_on_tick)

func _on_tick(_n: int, delta: float) -> void:
	_gather_player_inputs()
	_apply_player_movement(delta)
	_apply_other_systems(delta)

func _gather_player_inputs() -> void:
	_tick_context.clear()

	for peer_id in player_spawner.get_peer_ids():
		_tick_context[peer_id] = {
			"input": player_input_handler.get_next_input(peer_id),
		}

func _apply_player_movement(delta: float) -> void:
	for peer_id in _tick_context:
		var player: PhysicsBody = player_spawner.get_player(peer_id)
		if player == null:
			continue

		player.simulate(_tick_context[peer_id]["input"], delta)

func _apply_other_systems(_delta: float) -> void:
	pass
