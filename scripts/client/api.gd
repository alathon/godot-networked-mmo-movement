class_name API
extends Node

signal movement_snapshot_received(entities: Array[Dictionary])
signal entity_lifecycle_received(entities_spawned: Array[Dictionary], entities_despawned: Array[Dictionary], controlled_entity_id: int)

const DEFAULT_SERVER_HOST := "127.0.0.1"
const DEFAULT_SERVER_PORT := 4242
const CHANNEL_MOVEMENT := 0
const CHANNEL_MOVEMENT_SNAPSHOT := 1
const CHANNEL_ENTITY_LIFECYCLE := 2
const CHANNEL_COUNT := 3

var _connection: ENetConnection
var _server_peer: ENetPacketPeer

func _ready() -> void:
	connect_to_server()

func _process(_delta: float) -> void:
	poll()

func _exit_tree() -> void:
	disconnect_from_server()

func connect_to_server(host := DEFAULT_SERVER_HOST, port := DEFAULT_SERVER_PORT) -> Error:
	if _server_peer != null and _server_peer.get_state() != ENetPacketPeer.STATE_DISCONNECTED:
		return OK

	_connection = ENetConnection.new()
	var err := _connection.create_host(1, CHANNEL_COUNT)
	if err != OK:
		push_error("Client ENet host creation failed: %s" % error_string(err))
		_connection = null
		return err

	_server_peer = _connection.connect_to_host(host, port, CHANNEL_COUNT)
	if _server_peer == null:
		push_error("Client ENet connect failed for %s:%d" % [host, port])
		_connection = null
		return ERR_CANT_CONNECT

	return OK

func send_player_input(input: Dictionary, previous_frame = null) -> Error:
	var err := connect_to_server()
	if err != OK:
		return err

	poll()
	if _server_peer.get_state() != ENetPacketPeer.STATE_CONNECTED:
		return ERR_BUSY

	var bytes := MovementInputCodec.encode_packet(input, previous_frame)
	return _server_peer.send(CHANNEL_MOVEMENT, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)

func disconnect_from_server() -> void:
	if _server_peer != null and _server_peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
		_server_peer.peer_disconnect()
		if _connection != null:
			_connection.flush()

	_disconnect()

func poll() -> void:
	if _connection == null:
		return

	while true:
		var event := _connection.service(0)
		var event_type: int = event[0]

		if event_type == ENetConnection.EVENT_NONE:
			return

		if event_type == ENetConnection.EVENT_ERROR:
			push_error("Client ENet service error")
			_disconnect()
			return

		match event_type:
			ENetConnection.EVENT_DISCONNECT:
				_disconnect()
				return
			ENetConnection.EVENT_RECEIVE:
				var peer: ENetPacketPeer = event[1]
				var channel: int = event[3]
				if channel == CHANNEL_MOVEMENT_SNAPSHOT:
					_receive_movement_snapshot(peer.get_packet())
				elif channel == CHANNEL_ENTITY_LIFECYCLE:
					_receive_entity_lifecycle(peer.get_packet())
				else:
					peer.get_packet()

func _disconnect() -> void:
	if _connection != null:
		_connection.destroy()
	_connection = null
	_server_peer = null

func _receive_movement_snapshot(bytes: PackedByteArray) -> void:
	var entities := MovementSnapshotCodec.decode_packet(bytes)
	if entities.is_empty():
		return

	movement_snapshot_received.emit(entities)

func _receive_entity_lifecycle(bytes: PackedByteArray) -> void:
	var lifecycle := EntityLifecycleCodec.decode_packet(bytes)
	var entities_spawned: Array[Dictionary] = lifecycle["entities_spawned"]
	var entities_despawned: Array[Dictionary] = lifecycle["entities_despawned"]
	var controlled_entity_id := int(lifecycle["controlled_entity_id"])

	if (
		entities_spawned.is_empty()
		and entities_despawned.is_empty()
		and controlled_entity_id == EntityLifecycleCodec.NO_ENTITY_ID
	):
		return

	entity_lifecycle_received.emit(entities_spawned, entities_despawned, controlled_entity_id)
