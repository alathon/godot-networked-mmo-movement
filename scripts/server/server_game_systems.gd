extends Node

@onready var ticker: Ticker = %Ticker
@onready var entity_tracker: EntityTracker = %EntityTracker
@onready var player_input_handler: Node = %PlayerInputHandler
@onready var server_network: Node = %ServerNetwork

@export var debug_force_reconciliation_drift: bool = false
@export var debug_drift_interval_ticks: int = 60
@export var debug_drift_offset: Vector3 = Vector3(1.0, 0.0, 0.0)

var _tick_context: Dictionary[int, Dictionary] = {}

func _ready() -> void:
	ticker.tick.connect(_on_tick)

func _on_tick(n: int, delta: float) -> void:
	_gather_player_inputs()
	_apply_player_movement(delta)
	_apply_debug_reconciliation_drift(n)
	_apply_other_systems(delta)
	_broadcast_movement_snapshot(n)

func _gather_player_inputs() -> void:
	_tick_context.clear()

	var players: Dictionary = entity_tracker.get_players()
	for peer_id in players:
		_tick_context[peer_id] = {
			"input": player_input_handler.get_next_input(peer_id),
		}

func _apply_player_movement(delta: float) -> void:
	var players: Dictionary = entity_tracker.get_players()
	for peer_id in _tick_context:
		var player: ServerPlayerEntity = players[peer_id]
		player.get_body().simulate(_tick_context[peer_id]["input"], delta)

func _apply_other_systems(_delta: float) -> void:
	pass

func _apply_debug_reconciliation_drift(tick: int) -> void:
	if not debug_force_reconciliation_drift:
		return
	if debug_drift_interval_ticks <= 0 or tick % debug_drift_interval_ticks != 0:
		return

	var players: Dictionary = entity_tracker.get_players()
	for peer_id in _tick_context:
		var input: MovementInputFrame = _tick_context[peer_id]["input"]
		if not _has_movement_input(input):
			continue

		var player: ServerPlayerEntity = players[peer_id]
		var body: PhysicsBody = player.get_body()
		body.global_position += debug_drift_offset
		print(
			"debug_reconciliation_drift tick=%d peer=%d entity=%d offset=%s position=%s" %
			[tick, peer_id, player.entity_id, debug_drift_offset, body.global_position]
		)

func _broadcast_movement_snapshot(server_tick: int) -> void:
	var entities: Array[MovementSnapshotMsg.EntitySnapshot] = []

	var players: Dictionary = entity_tracker.get_players()
	for peer_id in players:
		var player: ServerPlayerEntity = players[peer_id]
		var body: PhysicsBody = player.get_body()
		var snapshot = MovementSnapshotMsg.EntitySnapshot.new()
		snapshot.entity_id = player.entity_id
		snapshot.last_processed_movement_seq = player_input_handler.get_last_processed_seq(peer_id)
		snapshot.position = body.global_position
		snapshot.velocity = body.velocity
		snapshot.rotation = body.global_transform.basis.get_rotation_quaternion()
		snapshot.is_on_floor = body.is_on_floor()
		entities.append(snapshot)

	if entities.is_empty():
		return

	server_network.broadcast_movement_snapshot(MovementSnapshotMsg.encode(entities, server_tick))

func _has_movement_input(input: MovementInputFrame) -> bool:
	return absf(input.input_x) > 0.001 or absf(input.input_z) > 0.001 or input.jump_pressed
