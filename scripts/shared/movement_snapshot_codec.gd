class_name MovementSnapshotCodec
extends RefCounted

const VERSION := 1
const HEADER_SIZE := 4
const ENTITY_SIZE := 34

const FLAG_ON_FLOOR := 1

const POSITION_SCALE := 1000.0
const VELOCITY_SCALE := 100.0
const QUAT_COMPONENT_LIMIT := 0.7071067811865476
const QUAT_SCALE := 32767.0 / QUAT_COMPONENT_LIMIT
const NO_PROCESSED_SEQ := 0xFFFFFFFF

static func encode_packet(entities: Array) -> PackedByteArray:
	var count := mini(entities.size(), 0xFFFF)
	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE + count * ENTITY_SIZE)

	var offset := 0
	offset = _write_u8(bytes, offset, VERSION)
	offset = _write_u8(bytes, offset, 0)
	offset = _write_u16(bytes, offset, count)

	for i in count:
		var entity: Dictionary = entities[i]
		var position := _quantize_position(_get_vector3(entity, "position", "pos"))
		var velocity := _quantize_velocity(_get_vector3(entity, "velocity", "vel"))
		var rotation := _get_quaternion(entity, "rotation", "rot")
		var last_processed_seq := int(entity.get("last_processed_movement_seq", NO_PROCESSED_SEQ))

		offset = _write_u32(bytes, offset, int(entity["entity_id"]))
		offset = _write_u32(bytes, offset, last_processed_seq)
		offset = _write_i32(bytes, offset, position.x)
		offset = _write_i32(bytes, offset, position.y)
		offset = _write_i32(bytes, offset, position.z)
		offset = _write_i16(bytes, offset, velocity.x)
		offset = _write_i16(bytes, offset, velocity.y)
		offset = _write_i16(bytes, offset, velocity.z)
		offset = _write_quaternion(bytes, offset, rotation)
		offset = _write_u8(bytes, offset, FLAG_ON_FLOOR if bool(entity.get("is_on_floor", false)) else 0)

	return bytes

static func decode_packet(bytes: PackedByteArray) -> Array[Dictionary]:
	if bytes.size() < HEADER_SIZE:
		return []

	var offset := 0
	var version := _read_u8(bytes, offset)
	offset += 1
	if version != VERSION:
		return []

	offset += 1 # reserved flags
	var count := _read_u16(bytes, offset)
	offset += 2

	if bytes.size() < HEADER_SIZE + count * ENTITY_SIZE:
		return []

	var entities: Array[Dictionary] = []
	entities.resize(count)

	for i in count:
		var entity_id := _read_u32(bytes, offset)
		offset += 4
		var last_processed_seq := _read_u32(bytes, offset)
		offset += 4

		var position := Vector3i(
			_read_i32(bytes, offset),
			_read_i32(bytes, offset + 4),
			_read_i32(bytes, offset + 8)
		)
		offset += 12

		var velocity := Vector3i(
			_read_i16(bytes, offset),
			_read_i16(bytes, offset + 2),
			_read_i16(bytes, offset + 4)
		)
		offset += 6

		var rotation := _read_quaternion(bytes, offset)
		offset += 7

		var flags := _read_u8(bytes, offset)
		offset += 1

		entities[i] = {
			"entity_id": entity_id,
			"last_processed_movement_seq": last_processed_seq,
			"position": _dequantize_position(position),
			"velocity": _dequantize_velocity(velocity),
			"rotation": rotation,
			"is_on_floor": bool(flags & FLAG_ON_FLOOR),
		}

	return entities

static func _quantize_position(value: Vector3) -> Vector3i:
	return Vector3i(
		_clamp_i32(roundi(value.x * POSITION_SCALE)),
		_clamp_i32(roundi(value.y * POSITION_SCALE)),
		_clamp_i32(roundi(value.z * POSITION_SCALE))
	)

static func _dequantize_position(value: Vector3i) -> Vector3:
	return Vector3(value) / POSITION_SCALE

static func _quantize_velocity(value: Vector3) -> Vector3i:
	return Vector3i(
		_clamp_i16(roundi(value.x * VELOCITY_SCALE)),
		_clamp_i16(roundi(value.y * VELOCITY_SCALE)),
		_clamp_i16(roundi(value.z * VELOCITY_SCALE))
	)

static func _dequantize_velocity(value: Vector3i) -> Vector3:
	return Vector3(value) / VELOCITY_SCALE

static func _get_vector3(entity: Dictionary, primary_key: String, fallback_key: String) -> Vector3:
	if entity.has(primary_key):
		return entity[primary_key]
	return entity.get(fallback_key, Vector3.ZERO)

static func _get_quaternion(entity: Dictionary, primary_key: String, fallback_key: String) -> Quaternion:
	var value = entity[primary_key] if entity.has(primary_key) else entity.get(fallback_key, Quaternion.IDENTITY)
	if value is Quaternion:
		return (value as Quaternion).normalized()
	if value is Basis:
		return (value as Basis).get_rotation_quaternion().normalized()
	return Quaternion.IDENTITY

static func _write_quaternion(bytes: PackedByteArray, offset: int, value: Quaternion) -> int:
	var q := value.normalized()
	var components := [q.x, q.y, q.z, q.w]
	var largest_index := 0
	var largest_abs := absf(components[0])

	for i in range(1, 4):
		var component_abs := absf(components[i])
		if component_abs > largest_abs:
			largest_abs = component_abs
			largest_index = i

	if components[largest_index] < 0.0:
		for i in 4:
			components[i] = -components[i]

	offset = _write_u8(bytes, offset, largest_index)
	for i in 4:
		if i == largest_index:
			continue
		offset = _write_i16(bytes, offset, _clamp_i16(roundi(components[i] * QUAT_SCALE)))

	return offset

static func _read_quaternion(bytes: PackedByteArray, offset: int) -> Quaternion:
	var largest_index := _read_u8(bytes, offset)
	offset += 1

	var components := [0.0, 0.0, 0.0, 0.0]
	var sum_squares := 0.0
	for i in 4:
		if i == largest_index:
			continue

		var component := float(_read_i16(bytes, offset)) / QUAT_SCALE
		offset += 2
		components[i] = component
		sum_squares += component * component

	components[largest_index] = sqrt(maxf(0.0, 1.0 - sum_squares))
	return Quaternion(components[0], components[1], components[2], components[3]).normalized()

static func _write_u8(bytes: PackedByteArray, offset: int, value: int) -> int:
	bytes[offset] = value & 0xFF
	return offset + 1

static func _write_u16(bytes: PackedByteArray, offset: int, value: int) -> int:
	bytes[offset] = value & 0xFF
	bytes[offset + 1] = (value >> 8) & 0xFF
	return offset + 2

static func _write_i16(bytes: PackedByteArray, offset: int, value: int) -> int:
	return _write_u16(bytes, offset, value & 0xFFFF)

static func _write_u32(bytes: PackedByteArray, offset: int, value: int) -> int:
	bytes[offset] = value & 0xFF
	bytes[offset + 1] = (value >> 8) & 0xFF
	bytes[offset + 2] = (value >> 16) & 0xFF
	bytes[offset + 3] = (value >> 24) & 0xFF
	return offset + 4

static func _write_i32(bytes: PackedByteArray, offset: int, value: int) -> int:
	return _write_u32(bytes, offset, value & 0xFFFFFFFF)

static func _read_u8(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset]

static func _read_u16(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)

static func _read_i16(bytes: PackedByteArray, offset: int) -> int:
	var value := _read_u16(bytes, offset)
	return value - 0x10000 if value >= 0x8000 else value

static func _read_u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)

static func _read_i32(bytes: PackedByteArray, offset: int) -> int:
	var value := _read_u32(bytes, offset)
	return value - 0x100000000 if value >= 0x80000000 else value

static func _clamp_i16(value: int) -> int:
	return clampi(value, -0x8000, 0x7FFF)

static func _clamp_i32(value: int) -> int:
	return clampi(value, -0x80000000, 0x7FFFFFFF)
