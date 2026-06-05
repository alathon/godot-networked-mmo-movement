class_name ClientPlayerSpawner
extends Node

const PLAYER_ENTITY = preload("res://scripts/client/player_entity.tscn")
const REMOTE_ENTITY = preload("res://scripts/client/remote_entity.tscn")
const EntityLifecycleCodecScript = preload("res://scripts/shared/entity_lifecycle_codec.gd")

@onready var entities: Node = %Entities
@onready var api: API = $"../API"

var local_entity_id := -1
var _local_player: Player
var _players_by_entity_id: Dictionary[int, BaseEntity] = {}

func _ready() -> void:
	api.entity_lifecycle_received.connect(_on_entity_lifecycle_received)

func get_local_player() -> Player:
	return _local_player

func get_player(entity_id: int) -> BaseEntity:
	return _players_by_entity_id.get(entity_id)

func get_players() -> Dictionary:
	return _players_by_entity_id

func _on_entity_lifecycle_received(
	entities_spawned: Array[Dictionary],
	entities_despawned: Array[Dictionary],
	controlled_entity_id: int
) -> void:
	if controlled_entity_id != EntityLifecycleCodecScript.NO_ENTITY_ID:
		_set_local_entity_id(controlled_entity_id)

	for despawn in entities_despawned:
		despawn_entity(int(despawn["entity_id"]))

	for spawn in entities_spawned:
		spawn_entity(spawn)

func spawn_entity(spawn: Dictionary) -> BaseEntity:
	if int(spawn.get("entity_kind", EntityLifecycleCodecScript.ENTITY_KIND_PLAYER)) != EntityLifecycleCodecScript.ENTITY_KIND_PLAYER:
		push_warning("Ignoring unknown entity kind in spawn: %s" % spawn)
		return null

	var entity_id := int(spawn["entity_id"])
	if entity_id == local_entity_id:
		return _spawn_local_player(spawn)

	return _spawn_remote_player(spawn)

func despawn_entity(entity_id: int) -> void:
	var player := _players_by_entity_id.get(entity_id) as Node
	if player == null:
		return

	_players_by_entity_id.erase(entity_id)
	if player == _local_player:
		_local_player = null
		local_entity_id = -1

	player.queue_free()
	print("Despawned entity=%d" % entity_id)

func _set_local_entity_id(entity_id: int) -> void:
	if local_entity_id == entity_id:
		return

	if _local_player != null:
		despawn_entity(local_entity_id)

	local_entity_id = entity_id

func _spawn_local_player(spawn: Dictionary) -> Player:
	if _local_player != null:
		_apply_spawn_transform(_local_player, spawn)
		return _local_player

	var stale_remote := _players_by_entity_id.get(local_entity_id) as Node
	if stale_remote != null:
		_players_by_entity_id.erase(local_entity_id)
		stale_remote.queue_free()

	var player: Player = PLAYER_ENTITY.instantiate()
	player.name = "PlayerEntity"
	player.entity_id = local_entity_id

	entities.add_child(player)
	_apply_spawn_transform(player, spawn)

	_local_player = player
	_players_by_entity_id[local_entity_id] = player

	print("Spawned local player entity=%d" % local_entity_id)
	return player

func _spawn_remote_player(spawn: Dictionary) -> RemoteEntity:
	var entity_id := int(spawn["entity_id"])
	var existing := _players_by_entity_id.get(entity_id) as RemoteEntity
	if existing != null:
		_apply_spawn_transform(existing, spawn)
		return existing

	var remote: RemoteEntity = REMOTE_ENTITY.instantiate()
	remote.name = "Remote_%d" % entity_id
	remote.entity_id = entity_id

	entities.add_child(remote)
	_apply_spawn_transform(remote, spawn)
	_players_by_entity_id[entity_id] = remote

	print("Spawned remote player entity=%d" % entity_id)
	return remote

func _apply_spawn_transform(entity: BaseEntity, spawn: Dictionary) -> void:
	var position: Vector3 = spawn.get("position", Vector3.ZERO)
	var rotation: Quaternion = spawn.get("rotation", Quaternion.IDENTITY)
	var body: Node3D = entity.get_body()
	body.global_transform = Transform3D(Basis(rotation), position)

	if entity is RemoteEntity:
		(entity as RemoteEntity).apply_remote_transform(position, rotation)
