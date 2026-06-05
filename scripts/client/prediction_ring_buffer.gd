class_name PredictionRingBuffer
extends RefCounted

class Frame:
	var valid := false
	var seq := -1
	var input_x := 0.0
	var input_z := 0.0
	var jump_pressed := false
	var jump_down := false

	func write_from_input(input: Dictionary) -> void:
		valid = true
		seq = int(input.get("seq", 0))
		input_x = float(input.get("input_x", 0.0))
		input_z = float(input.get("input_z", 0.0))
		jump_pressed = bool(input.get("jump_pressed", false))
		jump_down = bool(input.get("jump_down", false))

	func write_to_message(message) -> void:
		message.set_seq(seq)
		message.set_input_x(input_x)
		message.set_input_z(input_z)
		message.set_jump_pressed(jump_pressed)
		message.set_jump_down(jump_down)

var _frames: Array[Frame] = []
var _size := 0

func _init(size := 30) -> void:
	_size = maxi(size, 1)
	_frames.resize(_size)

	for i in _size:
		_frames[i] = Frame.new()

func store(input: Dictionary) -> Frame:
	var seq := int(input.get("seq", 0))
	var frame := _frames[_index_for_seq(seq)]
	frame.write_from_input(input)
	return frame

func get_frame(seq: int) -> Frame:
	var frame := _frames[_index_for_seq(seq)]
	if frame.valid and frame.seq == seq:
		return frame
	return null

func get_previous_frame(seq: int) -> Frame:
	return get_frame(seq - 1)

func _index_for_seq(seq: int) -> int:
	return posmod(seq, _size)
