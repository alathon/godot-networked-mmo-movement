extends Node

const SERVER_PLAYER_ENTITY = preload("res://scripts/server/server_player_entity.tscn")
const EntityLifecycleCodecScript = preload("res://scripts/shared/entity_lifecycle_codec.gd")
const SPAWN_POSITION := Vector3(-39.976143, 0.7148186, -40.79889)

@onready var entities: Node = %Entities
@onready var server_network: Node = %ServerNetwork

var _players_by_peer_id: Dictionary = {}
var _next_entity_id := 1

func _ready() -> void:
	server_network.player_connected.connect(_on_player_connected)
	server_network.player_disconnected.connect(_on_player_disconnected)

func get_player(peer_id: int) -> ServerPlayerEntity:
	return _players_by_peer_id.get(peer_id) as ServerPlayerEntity

func get_players() -> Dictionary:
	return _players_by_peer_id

func get_peer_ids() -> Array:
	return _players_by_peer_id.keys()

func _on_player_connected(peer_id: int) -> void:
	if _players_by_peer_id.has(peer_id):
		return

	var player := SERVER_PLAYER_ENTITY.instantiate() as ServerPlayerEntity
	player.name = "Player_%d" % peer_id
	player.entity_id = _next_entity_id
	_next_entity_id += 1

	entities.add_child(player)
	player.get_body().global_position = SPAWN_POSITION
	_players_by_peer_id[peer_id] = player
	_send_initial_lifecycle(peer_id, player.entity_id)
	_broadcast_spawn(player, [peer_id])

	print("Spawned server player entity=%d for peer %d" % [player.entity_id, peer_id])

func _on_player_disconnected(peer_id: int) -> void:
	var player := _players_by_peer_id.get(peer_id) as ServerPlayerEntity
	if player == null:
		return

	var entity_id := player.entity_id
	_players_by_peer_id.erase(peer_id)
	player.queue_free()
	_broadcast_despawn(entity_id)

	print("Removed server player entity=%d for peer %d" % [entity_id, peer_id])

func _send_initial_lifecycle(peer_id: int, controlled_entity_id: int) -> void:
	var spawns: Array[Dictionary] = []
	for player in _players_by_peer_id.values():
		spawns.append(_make_spawn_record(player))

	var bytes := EntityLifecycleCodecScript.encode_packet(spawns, [], controlled_entity_id)
	server_network.send_entity_lifecycle(peer_id, bytes)

func _broadcast_spawn(player: ServerPlayerEntity, excluded_peer_ids: Array[int] = []) -> void:
	var bytes := EntityLifecycleCodecScript.encode_packet([_make_spawn_record(player)], [])
	server_network.broadcast_entity_lifecycle(bytes, excluded_peer_ids)

func _broadcast_despawn(entity_id: int) -> void:
	var bytes := EntityLifecycleCodecScript.encode_packet([], [{"entity_id": entity_id}])
	server_network.broadcast_entity_lifecycle(bytes)

func _make_spawn_record(player: ServerPlayerEntity) -> Dictionary:
	var body: PhysicsBody = player.get_body()
	return {
		"entity_id": player.entity_id,
		"entity_kind": EntityLifecycleCodecScript.ENTITY_KIND_PLAYER,
		"position": body.global_position,
		"rotation": body.global_transform.basis.get_rotation_quaternion(),
	}
