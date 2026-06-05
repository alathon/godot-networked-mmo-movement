extends Node

const SERVER_PLAYER_ENTITY = preload("res://scripts/server/server_player_entity.tscn")
const SPAWN_POSITION := Vector3(-39.976143, 0.7148186, -40.79889)

@onready var entities: Node = %Entities
@onready var server_network: Node = %ServerNetwork

var _players_by_peer_id: Dictionary = {}

func _ready() -> void:
	server_network.player_connected.connect(_on_player_connected)
	server_network.player_disconnected.connect(_on_player_disconnected)

func get_player(peer_id: int) -> PhysicsBody:
	return _players_by_peer_id.get(peer_id) as PhysicsBody

func get_peer_ids() -> Array:
	return _players_by_peer_id.keys()

func _on_player_connected(peer_id: int) -> void:
	if _players_by_peer_id.has(peer_id):
		return

	var player := SERVER_PLAYER_ENTITY.instantiate() as PhysicsBody
	player.name = "Player_%d" % peer_id
	player.position = SPAWN_POSITION

	entities.add_child(player)
	_players_by_peer_id[peer_id] = player

	print("Spawned server player for peer %d" % peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	var player := _players_by_peer_id.get(peer_id) as Node
	if player == null:
		return

	_players_by_peer_id.erase(peer_id)
	player.queue_free()

	print("Removed server player for peer %d" % peer_id)
