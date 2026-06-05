extends Node

class PeerBuffer:
	var peer_id := -1
	var last_seen_seq := -1
	var last_processed_seq := -1
	var last_held_input: Dictionary = {}
	var inputs_by_seq: Dictionary = {}

	func _init(p_peer_id: int) -> void:
		peer_id = p_peer_id
		last_held_input = {
			"seq": -1,
			"input_x": 0.0,
			"input_z": 0.0,
			"jump_pressed": false,
			"jump_down": false,
			"synthetic": true,
		}

@onready var server_network: Node = %ServerNetwork

var _buffers_by_peer_id: Dictionary = {}

func _ready() -> void:
	server_network.player_input_received.connect(_on_player_input_received)
	server_network.player_connected.connect(_on_player_connected)
	server_network.player_disconnected.connect(_on_player_disconnected)

func get_next_input(peer_id: int) -> Dictionary:
	var peer_buffer := _get_peer_buffer(peer_id)
	if peer_buffer == null:
		return empty_input(-1)

	if not peer_buffer.inputs_by_seq.is_empty():
		var seq := _get_lowest_buffered_seq(peer_buffer.inputs_by_seq)
		var input: Dictionary = peer_buffer.inputs_by_seq[seq]
		peer_buffer.inputs_by_seq.erase(seq)
		input["synthetic"] = false
		peer_buffer.last_processed_seq = seq
		peer_buffer.last_held_input = input
		return input.duplicate(true)

	var synthetic := _make_synthetic_input(peer_buffer)
	peer_buffer.last_held_input = synthetic
	return synthetic

func _on_player_input_received(peer_id: int, input: Dictionary) -> void:
	var peer_buffer := _get_peer_buffer(peer_id)
	if peer_buffer == null:
		return

	var seq := int(input.get("seq", 0))
	if seq <= peer_buffer.last_seen_seq:
		return

	peer_buffer.last_seen_seq = seq
	peer_buffer.inputs_by_seq[seq] = input.duplicate(true)

func _on_player_connected(peer_id: int) -> void:
	_buffers_by_peer_id[peer_id] = PeerBuffer.new(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	_buffers_by_peer_id.erase(peer_id)

func _get_peer_buffer(peer_id: int) -> PeerBuffer:
	return _buffers_by_peer_id.get(peer_id) as PeerBuffer

func _get_lowest_buffered_seq(buffer: Dictionary) -> int:
	var lowest_seq := 0
	var has_lowest := false
	for seq in buffer.keys():
		var input_seq := int(seq)
		if not has_lowest or input_seq < lowest_seq:
			lowest_seq = input_seq
			has_lowest = true
	return lowest_seq

func _make_synthetic_input(peer_buffer: PeerBuffer) -> Dictionary:
	var input: Dictionary = peer_buffer.last_held_input.duplicate(true)
	input["seq"] = peer_buffer.last_processed_seq
	input["jump_pressed"] = false
	input["synthetic"] = true
	return input

static func empty_input(seq: int) -> Dictionary:
	return {
		"seq": seq,
		"input_x": 0.0,
		"input_z": 0.0,
		"jump_pressed": false,
		"jump_down": false,
		"synthetic": true,
	}
