class_name PredictionRingBuffer
extends RefCounted

class Frame:
	var valid := false
	var seq := -1
	var input_x := 0.0
	var input_z := 0.0
	var jump_pressed := false
	var jump_down := false
	var predicted_position := Vector3.ZERO

	func write_from_input(input: Dictionary) -> void:
		valid = true
		seq = int(input.get("seq", 0))
		input_x = float(input.get("input_x", 0.0))
		input_z = float(input.get("input_z", 0.0))
		jump_pressed = bool(input.get("jump_pressed", false))
		jump_down = bool(input.get("jump_down", false))

	func write_predicted_state(body: PhysicsBody) -> void:
		predicted_position = body.global_position

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

func get_predicted_position(seq: int):
	var frame := get_frame(seq)
	if frame == null:
		return Vector3.ZERO
	return frame.predicted_position

func _index_for_seq(seq: int) -> int:
	return posmod(seq, _size)
