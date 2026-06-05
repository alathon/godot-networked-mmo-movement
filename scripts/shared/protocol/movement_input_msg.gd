class_name MovementInputMsg
extends RefCounted

const MAGIC: int = MessageHeaders.MovementInputMsgHeader
const HEADER_SIZE := 2
const FRAME_SIZE := 9

const FLAG_HAS_PREVIOUS := 1
const FLAG_HAS_CURRENT := 2
const FRAME_FLAG_JUMP_PRESSED := 1
const FRAME_FLAG_JUMP_DOWN := 2
const AXIS_SCALE := 32767.0

static func encode(current_input: Variant, previous_input: Variant = null) -> PackedByteArray:
	var packet_flags = FLAG_HAS_CURRENT
	if previous_input != null:
		packet_flags |= FLAG_HAS_PREVIOUS

	var frame_count = 1 + (1 if previous_input != null else 0)
	var bytes = PackedByteArray()
	bytes.resize(HEADER_SIZE + frame_count * FRAME_SIZE)

	var offset = 0
	offset = ProtocolUtils.write_u8(bytes, offset, MAGIC)
	offset = ProtocolUtils.write_u8(bytes, offset, packet_flags)

	if previous_input != null:
		offset = _write_frame(bytes, offset, previous_input)
	offset = _write_frame(bytes, offset, current_input)

	return bytes

static func decode(bytes: PackedByteArray) -> MovementInputMsg:
	var msg = MovementInputMsg.new()
	if bytes.size() < HEADER_SIZE:
		return msg

	var offset = 0
	var magic = ProtocolUtils.read_u8(bytes, offset)
	offset += 1
	if magic != MAGIC:
		return msg

	var packet_flags = ProtocolUtils.read_u8(bytes, offset)
	offset += 1

	var expected_size = HEADER_SIZE
	if bool(packet_flags & FLAG_HAS_PREVIOUS):
		expected_size += FRAME_SIZE
	if bool(packet_flags & FLAG_HAS_CURRENT):
		expected_size += FRAME_SIZE

	if expected_size == HEADER_SIZE or bytes.size() < expected_size:
		return MovementInputMsg.new()

	if bool(packet_flags & FLAG_HAS_PREVIOUS):
		msg.inputs.append(_read_frame(bytes, offset))
		offset += FRAME_SIZE
	if bool(packet_flags & FLAG_HAS_CURRENT):
		msg.inputs.append(_read_frame(bytes, offset))

	return msg

static func encode_packet(current_input: Variant, previous_input: Variant = null) -> PackedByteArray:
	return encode(current_input, previous_input)

static func decode_packet(bytes: PackedByteArray) -> MovementInputMsg:
	return decode(bytes)

var inputs: Array[MovementInputFrame] = []

static func _write_frame(bytes: PackedByteArray, offset: int, input: Variant) -> int:
	offset = ProtocolUtils.write_u32(bytes, offset, ProtocolUtils.get_int(input, "seq", 0))
	offset = ProtocolUtils.write_i16(
		bytes,
		offset,
		ProtocolUtils.quantize_unit_float(ProtocolUtils.get_float(input, "input_x", 0.0), AXIS_SCALE)
	)
	offset = ProtocolUtils.write_i16(
		bytes,
		offset,
		ProtocolUtils.quantize_unit_float(ProtocolUtils.get_float(input, "input_z", 0.0), AXIS_SCALE)
	)

	var flags = 0
	if ProtocolUtils.get_bool(input, "jump_pressed", false):
		flags |= FRAME_FLAG_JUMP_PRESSED
	if ProtocolUtils.get_bool(input, "jump_down", false):
		flags |= FRAME_FLAG_JUMP_DOWN
	return ProtocolUtils.write_u8(bytes, offset, flags)

static func _read_frame(bytes: PackedByteArray, offset: int) -> MovementInputFrame:
	var frame = MovementInputFrame.new()
	frame.seq = ProtocolUtils.read_u32(bytes, offset)
	offset += 4
	frame.input_x = ProtocolUtils.dequantize_float(ProtocolUtils.read_i16(bytes, offset), AXIS_SCALE)
	offset += 2
	frame.input_z = ProtocolUtils.dequantize_float(ProtocolUtils.read_i16(bytes, offset), AXIS_SCALE)
	offset += 2
	var flags = ProtocolUtils.read_u8(bytes, offset)
	frame.jump_pressed = bool(flags & FRAME_FLAG_JUMP_PRESSED)
	frame.jump_down = bool(flags & FRAME_FLAG_JUMP_DOWN)
	return frame
