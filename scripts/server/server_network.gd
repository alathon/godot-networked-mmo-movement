extends Node

const MovementProto = preload("res://scripts/shared/movement_pb.gd")

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal player_input_received(peer_id: int, input: Dictionary)

const BIND_ADDRESS := "0.0.0.0"
const PORT := 4242
const CHANNEL_MOVEMENT := 0
const CHANNEL_MOVEMENT_SNAPSHOT := 1
const MAX_PEERS := 32
const CHANNEL_COUNT := 2

var _connection := ENetConnection.new()
var _peer_ids: Dictionary = {}
var _peers_by_id: Dictionary = {}
var _next_peer_id := 1

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
				var peer_id := _assign_peer_id(peer)
				print("Client connected: peer=%d %s:%d" % [peer_id, peer.get_remote_address(), peer.get_remote_port()])
				player_connected.emit(peer_id)
			ENetConnection.EVENT_DISCONNECT:
				var peer_id := _get_peer_id(peer)
				print("Client disconnected: peer=%d %s:%d" % [peer_id, peer.get_remote_address(), peer.get_remote_port()])
				_peer_ids.erase(_peer_key(peer))
				_peers_by_id.erase(peer_id)
				player_disconnected.emit(peer_id)
			ENetConnection.EVENT_RECEIVE:
				if event[3] == CHANNEL_MOVEMENT:
					_receive_movement_input(peer)

func _receive_movement_input(peer: ENetPacketPeer) -> void:
	var message := MovementProto.MovementInputPacket.new()
	var result: int = message.from_bytes(peer.get_packet())
	if result != MovementProto.PB_ERR.NO_ERRORS:
		push_warning("Dropped malformed MovementInputPacket packet: %s" % result)
		return

	var peer_id := _get_peer_id(peer)
	if message.has_previous_input():
		_receive_movement_input_frame(peer_id, message.get_previous_input())
	if message.has_current_input():
		_receive_movement_input_frame(peer_id, message.get_current_input())

func _receive_movement_input_frame(peer_id: int, message) -> void:
	var input := {
		"seq": message.get_seq(),
		"input_x": message.get_input_x(),
		"input_z": message.get_input_z(),
		"jump_pressed": message.get_jump_pressed(),
		"jump_down": message.get_jump_down(),
	}

	player_input_received.emit(peer_id, input)

	print(
		"input peer=%d seq=%d x=%.3f z=%.3f jump=%s down=%s" %
		[
			peer_id,
			input["seq"],
			input["input_x"],
			input["input_z"],
			input["jump_pressed"],
			input["jump_down"],
		]
	)

func _assign_peer_id(peer: ENetPacketPeer) -> int:
	var key := _peer_key(peer)
	var peer_id := _next_peer_id
	_next_peer_id += 1
	_peer_ids[key] = peer_id
	_peers_by_id[peer_id] = peer
	return peer_id

func broadcast_movement_snapshot(bytes: PackedByteArray) -> void:
	for peer in _peers_by_id.values():
		var packet_peer := peer as ENetPacketPeer
		if packet_peer == null:
			continue
		packet_peer.send(CHANNEL_MOVEMENT_SNAPSHOT, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)

func _get_peer_id(peer: ENetPacketPeer) -> int:
	return int(_peer_ids.get(_peer_key(peer), -1))

func _peer_key(peer: ENetPacketPeer) -> String:
	return "%s:%d" % [peer.get_remote_address(), peer.get_remote_port()]
