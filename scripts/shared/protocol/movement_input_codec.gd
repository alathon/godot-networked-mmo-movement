class_name MovementInputCodec
extends RefCounted

const VERSION := 1
const HEADER_SIZE := 2
const FRAME_SIZE := 9

const FLAG_HAS_PREVIOUS := 1
const FLAG_HAS_CURRENT := 2
const FRAME_FLAG_JUMP_PRESSED := 1
const FRAME_FLAG_JUMP_DOWN := 2
const AXIS_SCALE := 32767.0

static func encode_packet(current_input: Dictionary, previous_input = null) -> PackedByteArray:
	var packet_flags := FLAG_HAS_CURRENT
	if previous_input != null:
		packet_flags |= FLAG_HAS_PREVIOUS

	var frame_count := 1 + (1 if previous_input != null else 0)
	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE + frame_count * FRAME_SIZE)

	var offset := 0
	offset = _write_u8(bytes, offset, VERSION)
	offset = _write_u8(bytes, offset, packet_flags)

	if previous_input != null:
		offset = _write_frame(bytes, offset, previous_input)
	offset = _write_frame(bytes, offset, current_input)

	return bytes

static func decode_packet(bytes: PackedByteArray) -> Array[Dictionary]:
	if bytes.size() < HEADER_SIZE:
		return []

	var offset := 0
	var version := _read_u8(bytes, offset)
	offset += 1
	if version != VERSION:
		return []

	var packet_flags := _read_u8(bytes, offset)
	offset += 1

	var expected_size := HEADER_SIZE
	if bool(packet_flags & FLAG_HAS_PREVIOUS):
		expected_size += FRAME_SIZE
	if bool(packet_flags & FLAG_HAS_CURRENT):
		expected_size += FRAME_SIZE

	if expected_size == HEADER_SIZE or bytes.size() < expected_size:
		return []

	var inputs: Array[Dictionary] = []
	if bool(packet_flags & FLAG_HAS_PREVIOUS):
		inputs.append(_read_frame(bytes, offset))
		offset += FRAME_SIZE
	if bool(packet_flags & FLAG_HAS_CURRENT):
		inputs.append(_read_frame(bytes, offset))

	return inputs

static func _write_frame(bytes: PackedByteArray, offset: int, input) -> int:
	offset = _write_u32(bytes, offset, _get_int(input, "seq", 0))
	offset = _write_i16(bytes, offset, _quantize_axis(_get_float(input, "input_x", 0.0)))
	offset = _write_i16(bytes, offset, _quantize_axis(_get_float(input, "input_z", 0.0)))

	var flags := 0
	if _get_bool(input, "jump_pressed", false):
		flags |= FRAME_FLAG_JUMP_PRESSED
	if _get_bool(input, "jump_down", false):
		flags |= FRAME_FLAG_JUMP_DOWN
	return _write_u8(bytes, offset, flags)

static func _read_frame(bytes: PackedByteArray, offset: int) -> Dictionary:
	var seq := _read_u32(bytes, offset)
	offset += 4
	var input_x := _dequantize_axis(_read_i16(bytes, offset))
	offset += 2
	var input_z := _dequantize_axis(_read_i16(bytes, offset))
	offset += 2
	var flags := _read_u8(bytes, offset)

	return {
		"seq": seq,
		"input_x": input_x,
		"input_z": input_z,
		"jump_pressed": bool(flags & FRAME_FLAG_JUMP_PRESSED),
		"jump_down": bool(flags & FRAME_FLAG_JUMP_DOWN),
	}

static func _get_int(input, property: String, default_value: int) -> int:
	if input is Dictionary:
		return int(input.get(property, default_value))
	return int(input.get(property))

static func _get_float(input, property: String, default_value: float) -> float:
	if input is Dictionary:
		return float(input.get(property, default_value))
	return float(input.get(property))

static func _get_bool(input, property: String, default_value: bool) -> bool:
	if input is Dictionary:
		return bool(input.get(property, default_value))
	return bool(input.get(property))

static func _quantize_axis(value: float) -> int:
	return clampi(roundi(clampf(value, -1.0, 1.0) * AXIS_SCALE), -0x7FFF, 0x7FFF)

static func _dequantize_axis(value: int) -> float:
	return float(value) / AXIS_SCALE

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
