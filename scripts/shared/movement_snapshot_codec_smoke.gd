extends SceneTree

const MovementSnapshotCodecScript = preload("res://scripts/shared/movement_snapshot_codec.gd")

func _init() -> void:
	var server_tick := 1234
	var source := [{
		"entity_id": 7,
		"last_processed_movement_seq": 42,
		"position": Vector3(1.25, 2.5, -3.75),
		"velocity": Vector3(4.0, -5.0, 6.0),
		"rotation": Quaternion(Vector3.UP, 0.5),
		"is_on_floor": true,
	}]

	var bytes := MovementSnapshotCodecScript.encode_packet(source, server_tick)
	var entities := MovementSnapshotCodecScript.decode_packet(bytes)

	assert(entities.size() == 1)
	assert(int(entities[0]["entity_id"]) == 7)
	assert(int(entities[0]["server_tick"]) == server_tick)
	assert(int(entities[0]["last_processed_movement_seq"]) == 42)
	assert(entities[0]["position"].is_equal_approx(source[0]["position"]))
	assert(entities[0]["velocity"].is_equal_approx(source[0]["velocity"]))
	assert(bool(entities[0]["is_on_floor"]))

	print("movement_snapshot_codec_smoke ok")
	quit()
