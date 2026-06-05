class_name PlayerInput
extends Node

@export var body: PhysicsBody
@export var model: Node3D
@export var camera_pivot: Node3D

var _jump_was_down := false
var _movement_seq := 0
var _prediction_buffer = PredictionRingBuffer.new(30)
var _prediction_frame: Variant = null

func record_input(player: Player) -> Dictionary:
	var frame := player.gather_input()
	frame["seq"] = _movement_seq
	_movement_seq += 1
	_prediction_frame = _prediction_buffer.store(frame)
	return frame

func send_input_to_server(input: Dictionary) -> void:
	if _prediction_frame == null:
		return

	_prediction_frame.write_predicted_state(body)

	var api := _get_api()
	if api != null:
		var previous_frame: Variant = _prediction_buffer.get_previous_frame(_prediction_frame.seq)
		api.send_player_input(input, previous_frame)

	_prediction_frame = null

func get_predicted_position(seq: int) -> Vector3:
	return _prediction_buffer.get_predicted_position(seq)

func gather() -> Dictionary:
	var left := _is_pressed(&"move_left", KEY_A)
	var right := _is_pressed(&"move_right", KEY_D)
	var forward := _is_pressed(&"move_forward", KEY_W)
	var back := _is_pressed(&"move_back", KEY_S)
	var jump_down := _is_pressed(&"jump", KEY_SPACE)

	var local_input := Vector2(
		float(right) - float(left),
		float(back) - float(forward)
	)

	if local_input.length_squared() > 1.0:
		local_input = local_input.normalized()

	var movement := _to_world_movement(local_input)
	var frame := {
		"input_x": movement.x,
		"input_z": movement.z,
		"jump_pressed": jump_down and not _jump_was_down,
		"jump_down": jump_down,
	}

	_jump_was_down = jump_down
	return frame

func _to_world_movement(local_input: Vector2) -> Vector3:
	if local_input == Vector2.ZERO:
		return Vector3.ZERO

	var right := camera_pivot.global_transform.basis.x
	var forward := -camera_pivot.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()

	return (right * local_input.x + forward * -local_input.y).normalized()

func _is_pressed(action: StringName, key: Key) -> bool:
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		return true
	return Input.is_physical_key_pressed(key)
