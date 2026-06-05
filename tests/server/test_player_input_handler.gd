extends GutTest

func test_invalid_unsigned_seq_does_not_poison_peer_buffer() -> void:
	var handler: Node = autofree(load("res://scripts/server/player_input_handler.gd").new())
	handler._on_player_connected(3)

	var invalid_input: MovementInputFrame = _make_input(0xFFFFFFFF, -0.7, -0.7)
	handler._on_player_input_received(3, invalid_input)

	var valid_input: MovementInputFrame = _make_input(76, -0.7, -0.7)
	handler._on_player_input_received(3, valid_input)

	var next_input: MovementInputFrame = handler.get_next_input(3)
	assert_eq(next_input.seq, 76, "Invalid unsigned sentinel should not poison last_seen_seq")
	assert_almost_eq(next_input.input_x, -0.7, 0.001)
	assert_almost_eq(next_input.input_z, -0.7, 0.001)

func _make_input(seq: int, input_x: float, input_z: float) -> MovementInputFrame:
	var input: MovementInputFrame = MovementInputFrame.new()
	input.seq = seq
	input.input_x = input_x
	input.input_z = input_z
	return input
