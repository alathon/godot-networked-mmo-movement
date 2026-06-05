extends Node

const MovementSnapshotCodecScript = preload("res://scripts/shared/movement_snapshot_codec.gd")

@onready var ticker: Ticker = %Ticker
@onready var player_spawner: Node = %PlayerSpawner
@onready var player_input_handler: Node = %PlayerInputHandler
@onready var server_network: Node = %ServerNetwork

var _tick_context: Dictionary[int, Dictionary] = {}

func _ready() -> void:
	ticker.tick.connect(_on_tick)

func _on_tick(_n: int, delta: float) -> void:
	_gather_player_inputs()
	_apply_player_movement(delta)
	_apply_other_systems(delta)
	_broadcast_movement_snapshot()

func _gather_player_inputs() -> void:
	_tick_context.clear()

	var players: Dictionary = player_spawner.get_players()
	for peer_id in players:
		_tick_context[peer_id] = {
			"input": player_input_handler.get_next_input(peer_id),
		}

func _apply_player_movement(delta: float) -> void:
	var players: Dictionary = player_spawner.get_players()
	for peer_id in _tick_context:
		var player: PhysicsBody = players[peer_id]
		player.simulate(_tick_context[peer_id]["input"], delta)

func _apply_other_systems(_delta: float) -> void:
	pass

func _broadcast_movement_snapshot() -> void:
	var entities: Array[Dictionary] = []

	var players: Dictionary = player_spawner.get_players()
	for peer_id in players:
		var player: PhysicsBody = players[peer_id]
		entities.append({
			"entity_id": peer_id,
			"last_processed_movement_seq": player_input_handler.get_last_processed_seq(peer_id),
			"position": player.global_position,
			"velocity": player.velocity,
			"rotation": player.global_transform.basis.get_rotation_quaternion(),
			"is_on_floor": player.is_on_floor(),
		})

	if entities.is_empty():
		return

	server_network.broadcast_movement_snapshot(MovementSnapshotCodecScript.encode_packet(entities))
