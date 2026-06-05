extends Node

@export var body: PhysicsBody
@export var model: Node3D

var _jump_was_down := false

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

	var reference := _get_movement_reference()
	if reference == null:
		return Vector3(local_input.x, 0.0, local_input.y)

	var right := reference.global_transform.basis.x
	var forward := -reference.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()

	return (right * local_input.x + forward * -local_input.y).normalized()

func _get_movement_reference() -> Node3D:
	if body == null:
		return null
	return body.get_node_or_null("CameraPivot") as Node3D

func _is_pressed(action: StringName, key: Key) -> bool:
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		return true
	return Input.is_physical_key_pressed(key)
