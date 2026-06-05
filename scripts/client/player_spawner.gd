class_name ClientPlayerSpawner
extends Node

const PLAYER_ENTITY = preload("res://scripts/client/player_entity.tscn")
const REMOTE_ENTITY = preload("res://scripts/client/remote_entity.tscn")
const SPAWN_POSITION := Vector3(-39.976143, 0.7148186, -40.79889)

@onready var entities: Node = %Entities
@onready var api: API = $"../API"

var local_entity_id := -1
var _local_player: Player
var _players_by_entity_id: Dictionary = {}

func _ready() -> void:
	api.local_entity_id_received.connect(_on_local_entity_id_received)

func get_local_player() -> Player:
	return _local_player

func get_player(entity_id: int) -> BaseEntity:
	return _players_by_entity_id.get(entity_id) as BaseEntity

func get_players() -> Dictionary:
	return _players_by_entity_id

func ensure_remote_player(entity_id: int) -> RemoteEntity:
	if entity_id == local_entity_id:
		return null

	var existing := _players_by_entity_id.get(entity_id) as RemoteEntity
	if existing != null:
		return existing

	var remote := REMOTE_ENTITY.instantiate() as RemoteEntity
	remote.name = "Remote_%d" % entity_id
	remote.entity_id = entity_id

	entities.add_child(remote)
	_players_by_entity_id[entity_id] = remote

	print("Spawned remote player entity=%d" % entity_id)
	return remote

func _on_local_entity_id_received(entity_id: int) -> void:
	if _local_player != null:
		return

	local_entity_id = entity_id

	var player := PLAYER_ENTITY.instantiate() as Player
	player.name = "PlayerEntity"
	player.entity_id = entity_id

	entities.add_child(player)
	player.get_body().global_position = SPAWN_POSITION

	_local_player = player
	_players_by_entity_id[entity_id] = player

	print("Spawned local player entity=%d" % entity_id)
