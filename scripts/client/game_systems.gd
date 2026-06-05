extends Node

@onready var entities: Node = %Entities
@onready var ticker: Ticker = %Ticker

var _movement_seq := 0
var _prediction_buffer: Array[Dictionary] = []

func _ready() -> void:
	ticker.tick.connect(_on_tick)

func _on_tick(n: int, delta: float) -> void:
	var player := _get_local_player()
	if player == null:
		return

	var input := _gather_player_input(player)
	input["seq"] = _movement_seq
	_movement_seq += 1

	_store_prediction_frame(input)
	_apply_player_movement(player, input, delta)
	_apply_remote_entity_movement(player, delta)
	_send_player_input_to_server(input)

func _get_local_player() -> PhysicsBody:
	var player := entities.get_node_or_null("PlayerEntity")
	if player is PhysicsBody:
		return player

	for child in entities.get_children():
		if child is PhysicsBody:
			return child

	return null

func _gather_player_input(player: PhysicsBody) -> Dictionary:
	var input_node := player.get_node_or_null("PlayerInput")
	if input_node != null and input_node.has_method("gather"):
		return input_node.gather()
	return {}

func _apply_player_movement(player: PhysicsBody, input: Dictionary, delta: float) -> void:
	player.simulate(input, delta)

func _apply_remote_entity_movement(local_player: PhysicsBody, delta: float) -> void:
	for entity in entities.get_children():
		if entity == local_player:
			continue
		if entity.has_method("simulate_remote_tick"):
			entity.simulate_remote_tick(delta)

func _send_player_input_to_server(input: Dictionary) -> void:
	API.send_player_input(input)

func _store_prediction_frame(input: Dictionary) -> void:
	_prediction_buffer.append(input.duplicate(true))
