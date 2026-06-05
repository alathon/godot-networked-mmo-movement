extends Node

const MovementProto = preload("res://scripts/shared/movement_pb.gd")

const BIND_ADDRESS := "0.0.0.0"
const PORT := 4242
const CHANNEL_MOVEMENT := 0
const MAX_PEERS := 32
const CHANNEL_COUNT := 1

var _connection := ENetConnection.new()

func _ready() -> void:
	var err := _connection.create_host_bound(BIND_ADDRESS, PORT, MAX_PEERS, CHANNEL_COUNT)
	if err != OK:
		push_error("Server ENet bind failed on %s:%d: %s" % [BIND_ADDRESS, PORT, error_string(err)])
		return

	print("Server listening on %s:%d" % [BIND_ADDRESS, PORT])

func _process(_delta: float) -> void:
	_poll_network()

func _poll_network() -> void:
	while true:
		var event := _connection.service(0)
		var event_type: int = event[0]

		if event_type == ENetConnection.EVENT_NONE:
			return

		if event_type == ENetConnection.EVENT_ERROR:
			push_error("Server ENet service error")
			return

		var peer: ENetPacketPeer = event[1]
		match event_type:
			ENetConnection.EVENT_CONNECT:
				print("Client connected: %s:%d" % [peer.get_remote_address(), peer.get_remote_port()])
			ENetConnection.EVENT_DISCONNECT:
				print("Client disconnected: %s:%d" % [peer.get_remote_address(), peer.get_remote_port()])
			ENetConnection.EVENT_RECEIVE:
				if event[3] == CHANNEL_MOVEMENT:
					_receive_movement_input(peer)

func _receive_movement_input(peer: ENetPacketPeer) -> void:
	var message := MovementProto.MovementInput.new()
	var result: int = message.from_bytes(peer.get_packet())
	if result != MovementProto.PB_ERR.NO_ERRORS:
		push_warning("Dropped malformed MovementInput packet: %s" % result)
		return

	print(
		"input peer=%s:%d seq=%d x=%.3f z=%.3f jump=%s down=%s" %
		[
			peer.get_remote_address(),
			peer.get_remote_port(),
			message.get_seq(),
			message.get_input_x(),
			message.get_input_z(),
			message.get_jump_pressed(),
			message.get_jump_down(),
		]
	)
