extends SceneTree

const MovementInputCodecScript = preload("res://scripts/shared/movement_input_codec.gd")

class Frame:
	var seq := 41
	var input_x := -0.25
	var input_z := 0.75
	var jump_pressed := true
	var jump_down := true

func _init() -> void:
	var current := {
		"seq": 42,
		"input_x": 0.5,
		"input_z": -1.0,
		"jump_pressed": false,
		"jump_down": true,
	}

	var bytes := MovementInputCodecScript.encode_packet(current, Frame.new())
	var inputs := MovementInputCodecScript.decode_packet(bytes)

	assert(inputs.size() == 2)
	assert(int(inputs[0]["seq"]) == 41)
	assert(int(inputs[1]["seq"]) == 42)
	assert(is_equal_approx(float(inputs[0]["input_x"]), -0.25))
	assert(is_equal_approx(float(inputs[1]["input_x"]), 0.5))
	assert(bool(inputs[0]["jump_pressed"]))
	assert(not bool(inputs[1]["jump_pressed"]))
	assert(bool(inputs[1]["jump_down"]))

	print("movement_input_codec_smoke ok")
	quit()
