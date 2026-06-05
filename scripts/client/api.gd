class_name API
extends Node

const MovementProto = preload("res://scripts/shared/movement_pb.gd")

const DEFAULT_SERVER_HOST := "127.0.0.1"
const DEFAULT_SERVER_PORT := 4242
const CHANNEL_MOVEMENT := 0
const CHANNEL_COUNT := 1

static var _connection: ENetConnection
static var _server_peer: ENetPacketPeer

func _ready() -> void:
	API.connect_to_server()

func _process(_delta: float) -> void:
	API.poll()

static func connect_to_server(host := DEFAULT_SERVER_HOST, port := DEFAULT_SERVER_PORT) -> Error:
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

static func send_player_input(input: Dictionary) -> Error:
	var err := connect_to_server()
	if err != OK:
		return err

	poll()
	if _server_peer.get_state() != ENetPacketPeer.STATE_CONNECTED:
		return ERR_BUSY

	var message := MovementProto.MovementInput.new()
	message.set_seq(int(input.get("seq", 0)))
	message.set_input_x(float(input.get("input_x", 0.0)))
	message.set_input_z(float(input.get("input_z", 0.0)))
	message.set_jump_pressed(bool(input.get("jump_pressed", false)))
	message.set_jump_down(bool(input.get("jump_down", false)))

	return _server_peer.send(CHANNEL_MOVEMENT, message.to_bytes(), ENetPacketPeer.FLAG_UNSEQUENCED)

static func poll() -> void:
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
				peer.get_packet()

static func _disconnect() -> void:
	if _connection != null:
		_connection.destroy()
	_connection = null
	_server_peer = null
