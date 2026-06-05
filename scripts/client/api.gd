class_name API
extends Node

const MovementInputCodecScript = preload("res://scripts/shared/movement_input_codec.gd")
const MovementSnapshotCodecScript = preload("res://scripts/shared/movement_snapshot_codec.gd")

signal local_entity_id_received(entity_id: int)
signal movement_snapshot_received(entities: Array[Dictionary])

const DEFAULT_SERVER_HOST := "127.0.0.1"
const DEFAULT_SERVER_PORT := 4242
const CHANNEL_MOVEMENT := 0
const CHANNEL_MOVEMENT_SNAPSHOT := 1
const CHANNEL_IDENTITY := 2
const CHANNEL_COUNT := 3

var _connection: ENetConnection
var _server_peer: ENetPacketPeer

func _ready() -> void:
	connect_to_server()

func _process(_delta: float) -> void:
	poll()

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

	var bytes := MovementInputCodecScript.encode_packet(input, previous_frame)
	return _server_peer.send(CHANNEL_MOVEMENT, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)

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
				elif channel == CHANNEL_IDENTITY:
					_receive_local_entity_id(peer.get_packet())
				else:
					peer.get_packet()

func _disconnect() -> void:
	if _connection != null:
		_connection.destroy()
	_connection = null
	_server_peer = null

func _receive_movement_snapshot(bytes: PackedByteArray) -> void:
	var entities := MovementSnapshotCodecScript.decode_packet(bytes)
	if entities.is_empty():
		return

	movement_snapshot_received.emit(entities)

func _receive_local_entity_id(bytes: PackedByteArray) -> void:
	if bytes.size() < 4:
		return

	local_entity_id_received.emit(_read_u32(bytes, 0))

func _read_u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)
