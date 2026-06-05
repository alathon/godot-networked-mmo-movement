class_name EntityLifecycleCodec
extends RefCounted

const VERSION := 1
const HEADER_SIZE := 10
const SPAWN_RECORD_SIZE := 36
const DESPAWN_RECORD_SIZE := 8

const FLAG_HAS_CONTROLLED_ENTITY_ID := 1

const NO_ENTITY_ID := 0xFFFFFFFF
const ENTITY_KIND_PLAYER := 1
const DESPAWN_REASON_UNKNOWN := 0

static func encode_packet(
	entities_spawned: Array,
	entities_despawned: Array,
	controlled_entity_id := NO_ENTITY_ID
) -> PackedByteArray:
	var spawned_count := mini(entities_spawned.size(), 0xFFFF)
	var despawned_count := mini(entities_despawned.size(), 0xFFFF)
	var flags := FLAG_HAS_CONTROLLED_ENTITY_ID if controlled_entity_id != NO_ENTITY_ID else 0

	var bytes := PackedByteArray()
	bytes.resize(HEADER_SIZE + spawned_count * SPAWN_RECORD_SIZE + despawned_count * DESPAWN_RECORD_SIZE)

	var offset := 0
	offset = _write_u8(bytes, offset, VERSION)
	offset = _write_u8(bytes, offset, flags)
	offset = _write_u16(bytes, offset, spawned_count)
	offset = _write_u16(bytes, offset, despawned_count)
	offset = _write_u32(bytes, offset, controlled_entity_id)

	for i in spawned_count:
		offset = _write_spawn_record(bytes, offset, entities_spawned[i])

	for i in despawned_count:
		offset = _write_despawn_record(bytes, offset, entities_despawned[i])

	return bytes

static func decode_packet(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER_SIZE:
		return empty_packet()

	var offset := 0
	var version := _read_u8(bytes, offset)
	offset += 1
	if version != VERSION:
		return empty_packet()

	var flags := _read_u8(bytes, offset)
	offset += 1
	var spawned_count := _read_u16(bytes, offset)
	offset += 2
	var despawned_count := _read_u16(bytes, offset)
	offset += 2
	var controlled_entity_id := _read_u32(bytes, offset)
	offset += 4

	if not bool(flags & FLAG_HAS_CONTROLLED_ENTITY_ID):
		controlled_entity_id = NO_ENTITY_ID

	var expected_size := HEADER_SIZE + spawned_count * SPAWN_RECORD_SIZE + despawned_count * DESPAWN_RECORD_SIZE
	if bytes.size() < expected_size:
		return empty_packet()

	var entities_spawned: Array[Dictionary] = []
	entities_spawned.resize(spawned_count)
	for i in spawned_count:
		var result := _read_spawn_record(bytes, offset)
		entities_spawned[i] = result.record
		offset = result.offset

	var entities_despawned: Array[Dictionary] = []
	entities_despawned.resize(despawned_count)
	for i in despawned_count:
		var result := _read_despawn_record(bytes, offset)
		entities_despawned[i] = result.record
		offset = result.offset

	return {
		"controlled_entity_id": controlled_entity_id,
		"entities_spawned": entities_spawned,
		"entities_despawned": entities_despawned,
	}

static func empty_packet() -> Dictionary:
	return {
		"controlled_entity_id": NO_ENTITY_ID,
		"entities_spawned": [],
		"entities_despawned": [],
	}

static func _write_spawn_record(bytes: PackedByteArray, offset: int, entity: Dictionary) -> int:
	var position: Vector3 = entity.get("position", Vector3.ZERO)
	var rotation := _get_quaternion(entity.get("rotation", Quaternion.IDENTITY))

	offset = _write_u32(bytes, offset, int(entity["entity_id"]))
	offset = _write_u8(bytes, offset, int(entity.get("entity_kind", ENTITY_KIND_PLAYER)))
	offset = _write_u8(bytes, offset, 0)
	offset = _write_u16(bytes, offset, 0)
	offset = _write_float(bytes, offset, position.x)
	offset = _write_float(bytes, offset, position.y)
	offset = _write_float(bytes, offset, position.z)
	offset = _write_float(bytes, offset, rotation.x)
	offset = _write_float(bytes, offset, rotation.y)
	offset = _write_float(bytes, offset, rotation.z)
	offset = _write_float(bytes, offset, rotation.w)
	return offset

static func _read_spawn_record(bytes: PackedByteArray, offset: int) -> Dictionary:
	var entity_id := _read_u32(bytes, offset)
	offset += 4
	var entity_kind := _read_u8(bytes, offset)
	offset += 1
	offset += 1 # record flags
	offset += 2 # reserved

	var position := Vector3(
		_read_float(bytes, offset),
		_read_float(bytes, offset + 4),
		_read_float(bytes, offset + 8)
	)
	offset += 12

	var rotation := Quaternion(
		_read_float(bytes, offset),
		_read_float(bytes, offset + 4),
		_read_float(bytes, offset + 8),
		_read_float(bytes, offset + 12)
	).normalized()
	offset += 16

	return {
		"record": {
			"entity_id": entity_id,
			"entity_kind": entity_kind,
			"position": position,
			"rotation": rotation,
		},
		"offset": offset,
	}

static func _write_despawn_record(bytes: PackedByteArray, offset: int, entity: Dictionary) -> int:
	offset = _write_u32(bytes, offset, int(entity["entity_id"]))
	offset = _write_u8(bytes, offset, int(entity.get("reason", DESPAWN_REASON_UNKNOWN)))
	offset = _write_u8(bytes, offset, 0)
	offset = _write_u16(bytes, offset, 0)
	return offset

static func _read_despawn_record(bytes: PackedByteArray, offset: int) -> Dictionary:
	var entity_id := _read_u32(bytes, offset)
	offset += 4
	var reason := _read_u8(bytes, offset)
	offset += 1
	offset += 1 # record flags
	offset += 2 # reserved

	return {
		"record": {
			"entity_id": entity_id,
			"reason": reason,
		},
		"offset": offset,
	}

static func _get_quaternion(value) -> Quaternion:
	if value is Quaternion:
		return (value as Quaternion).normalized()
	if value is Basis:
		return (value as Basis).get_rotation_quaternion().normalized()
	return Quaternion.IDENTITY

static func _write_u8(bytes: PackedByteArray, offset: int, value: int) -> int:
	bytes[offset] = value & 0xFF
	return offset + 1

static func _write_u16(bytes: PackedByteArray, offset: int, value: int) -> int:
	bytes[offset] = value & 0xFF
	bytes[offset + 1] = (value >> 8) & 0xFF
	return offset + 2

static func _write_u32(bytes: PackedByteArray, offset: int, value: int) -> int:
	bytes[offset] = value & 0xFF
	bytes[offset + 1] = (value >> 8) & 0xFF
	bytes[offset + 2] = (value >> 16) & 0xFF
	bytes[offset + 3] = (value >> 24) & 0xFF
	return offset + 4

static func _write_float(bytes: PackedByteArray, offset: int, value: float) -> int:
	bytes.encode_float(offset, value)
	return offset + 4

static func _read_u8(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset]

static func _read_u16(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)

static func _read_u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)

static func _read_float(bytes: PackedByteArray, offset: int) -> float:
	return bytes.decode_float(offset)
