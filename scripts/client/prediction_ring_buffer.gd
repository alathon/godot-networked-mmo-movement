class_name PredictionRingBuffer
extends RefCounted

class Frame:
	var valid = false
	var seq = -1
	var input_x = 0.0
	var input_z = 0.0
	var jump_pressed = false
	var jump_down = false
	var predicted_position = Vector3.ZERO

	func write_from_input(input: MovementInputMsg.InputFrame) -> void:
		valid = true
		seq = input.seq
		input_x = input.input_x
		input_z = input.input_z
		jump_pressed = input.jump_pressed
		jump_down = input.jump_down

	func write_predicted_state(body: PhysicsBody) -> void:
		predicted_position = body.global_position

var _frames: Array[Frame] = []
var _size = 0

func _init(size := 30) -> void:
	_size = maxi(size, 1)
	_frames.resize(_size)

	for i in _size:
		_frames[i] = Frame.new()

func store(input: MovementInputMsg.InputFrame) -> Frame:
	var seq = input.seq
	var frame = _frames[_index_for_seq(seq)]
	frame.write_from_input(input)
	return frame

func get_frame(seq: int) -> Frame:
	var frame = _frames[_index_for_seq(seq)]
	if frame.valid and frame.seq == seq:
		return frame
	return null

func get_previous_frame(seq: int) -> Frame:
	return get_frame(seq - 1)

func get_predicted_position(seq: int):
	var frame = get_frame(seq)
	if frame == null:
		return null
	return frame.predicted_position

func _index_for_seq(seq: int) -> int:
	return posmod(seq, _size)
