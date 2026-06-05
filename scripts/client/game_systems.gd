extends Node

@onready var ticker: Ticker = %Ticker
@onready var api: API = $API
@onready var player_spawner: ClientPlayerSpawner = $PlayerSpawner

func _ready() -> void:
	ticker.tick.connect(_on_tick)
	api.movement_snapshot_received.connect(_on_movement_snapshot_received)

func _on_tick(_n: int, delta: float) -> void:
	var player: Player = player_spawner.get_local_player()
	if player == null:
		return

	var input: Dictionary = player.get_player_input().record_input(player)
	player.simulate(input, delta)
	_apply_remote_entities_movement(delta)
	player.get_player_input().send_input_to_server(input)

func _apply_remote_entities_movement(delta: float):
	for entity in player_spawner.entities:
		if entity is not RemoteEntity:
			continue
		
		var rentity: RemoteEntity = entity
		rentity.simulate(delta) # TODO: Remote interpolation somehow???

func _on_movement_snapshot_received(snapshot_entities: Array[Dictionary]) -> void:
	for snapshot in snapshot_entities:
		var entity_id := int(snapshot["entity_id"])
		if entity_id != player_spawner.local_entity_id:
			player_spawner.ensure_remote_player(entity_id)
			continue

		var seq := int(snapshot["last_processed_movement_seq"])
		if seq == MovementSnapshotCodec.NO_PROCESSED_SEQ:
			continue

		var player := player_spawner.get_local_player()
		if player == null:
			continue

		var player_input: PlayerInput = player.get_player_input()
		var predicted_position: Vector3 = player_input.get_predicted_position(seq)
		if predicted_position == null:
			print("snapshot seq=%d no local prediction frame" % seq)
			continue

		var authoritative_position: Vector3 = snapshot["position"]
		var diff: Vector3 = authoritative_position - predicted_position
		if diff.length() < 0.01:
			continue

		print(
			"snapshot seq=%d diff=(%.3f, %.3f, %.3f) len=%.3f predicted=%s authoritative=%s" %
			[
				seq,
				diff.x,
				diff.y,
				diff.z,
				diff.length(),
				predicted_position,
				authoritative_position,
			]
		)
