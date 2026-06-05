class_name EntityLifecycleMsg
extends RefCounted

const MAGIC: int = MessageHeaders.EntityLifecycleMsgHeader
const HEADER_SIZE := 10
const SPAWN_RECORD_SIZE := 36
const DESPAWN_RECORD_SIZE := 8

const FLAG_HAS_CONTROLLED_ENTITY_ID := 1

const NO_ENTITY_ID := 0xFFFFFFFF
const ENTITY_KIND_PLAYER := 1
const DESPAWN_REASON_UNKNOWN := 0

class SpawnRecord:
	var entity_id = 0
	var entity_kind = 1
	var position = Vector3.ZERO
	var rotation = Quaternion.IDENTITY

class DespawnRecord:
	var entity_id = 0
	var reason = 0

static func encode(
	entities_spawned: Array,
	entities_despawned: Array,
	controlled_entity_id: int = NO_ENTITY_ID
) -> PackedByteArray:
	var spawned_count = mini(entities_spawned.size(), 0xFFFF)
	var despawned_count = mini(entities_despawned.size(), 0xFFFF)
	var flags = FLAG_HAS_CONTROLLED_ENTITY_ID if controlled_entity_id != NO_ENTITY_ID else 0

	var bytes = PackedByteArray()
	bytes.resize(HEADER_SIZE + spawned_count * SPAWN_RECORD_SIZE + despawned_count * DESPAWN_RECORD_SIZE)

	var offset = 0
	offset = ProtocolUtils.write_u8(bytes, offset, MAGIC)
	offset = ProtocolUtils.write_u8(bytes, offset, flags)
	offset = ProtocolUtils.write_u16(bytes, offset, spawned_count)
	offset = ProtocolUtils.write_u16(bytes, offset, despawned_count)
	offset = ProtocolUtils.write_u32(bytes, offset, controlled_entity_id)

	for i in spawned_count:
		offset = _write_spawn_record(bytes, offset, entities_spawned[i])

	for i in despawned_count:
		offset = _write_despawn_record(bytes, offset, entities_despawned[i])

	return bytes

static func decode(bytes: PackedByteArray) -> EntityLifecycleMsg:
	if bytes.size() < HEADER_SIZE:
		return empty()

	var offset = 0
	var magic = ProtocolUtils.read_u8(bytes, offset)
	offset += 1
	if magic != MAGIC:
		return empty()

	var flags = ProtocolUtils.read_u8(bytes, offset)
	offset += 1
	var spawned_count = ProtocolUtils.read_u16(bytes, offset)
	offset += 2
	var despawned_count = ProtocolUtils.read_u16(bytes, offset)
	offset += 2
	var controlled_entity_id = ProtocolUtils.read_u32(bytes, offset)
	offset += 4

	if not bool(flags & FLAG_HAS_CONTROLLED_ENTITY_ID):
		controlled_entity_id = NO_ENTITY_ID

	var expected_size = HEADER_SIZE + spawned_count * SPAWN_RECORD_SIZE + despawned_count * DESPAWN_RECORD_SIZE
	if bytes.size() < expected_size:
		return empty()

	var msg = EntityLifecycleMsg.new()
	msg.controlled_entity_id = controlled_entity_id
	msg.entities_spawned.resize(spawned_count)
	for i in spawned_count:
		var result = _read_spawn_record(bytes, offset)
		msg.entities_spawned[i] = result.record
		offset = result.offset

	msg.entities_despawned.resize(despawned_count)
	for i in despawned_count:
		var result = _read_despawn_record(bytes, offset)
		msg.entities_despawned[i] = result.record
		offset = result.offset

	return msg

static func encode_packet(
	entities_spawned: Array,
	entities_despawned: Array,
	controlled_entity_id: int = NO_ENTITY_ID
) -> PackedByteArray:
	return encode(entities_spawned, entities_despawned, controlled_entity_id)

static func decode_packet(bytes: PackedByteArray) -> EntityLifecycleMsg:
	return decode(bytes)

static func empty() -> EntityLifecycleMsg:
	return EntityLifecycleMsg.new()

var controlled_entity_id = NO_ENTITY_ID
var entities_spawned: Array[SpawnRecord] = []
var entities_despawned: Array[DespawnRecord] = []

static func _write_spawn_record(bytes: PackedByteArray, offset: int, entity: Variant) -> int:
	var position = ProtocolUtils.get_vector3(entity, "position", Vector3.ZERO)
	var rotation = ProtocolUtils.get_quaternion(
		ProtocolUtils.get_value(entity, "rotation", Quaternion.IDENTITY)
	)

	offset = ProtocolUtils.write_u32(bytes, offset, ProtocolUtils.get_int(entity, "entity_id", 0))
	offset = ProtocolUtils.write_u8(
		bytes,
		offset,
		ProtocolUtils.get_int(entity, "entity_kind", ENTITY_KIND_PLAYER)
	)
	offset = ProtocolUtils.write_u8(bytes, offset, 0)
	offset = ProtocolUtils.write_u16(bytes, offset, 0)
	offset = ProtocolUtils.write_float(bytes, offset, position.x)
	offset = ProtocolUtils.write_float(bytes, offset, position.y)
	offset = ProtocolUtils.write_float(bytes, offset, position.z)
	offset = ProtocolUtils.write_float(bytes, offset, rotation.x)
	offset = ProtocolUtils.write_float(bytes, offset, rotation.y)
	offset = ProtocolUtils.write_float(bytes, offset, rotation.z)
	offset = ProtocolUtils.write_float(bytes, offset, rotation.w)
	return offset

static func _read_spawn_record(bytes: PackedByteArray, offset: int) -> Dictionary:
	var record = SpawnRecord.new()
	record.entity_id = ProtocolUtils.read_u32(bytes, offset)
	offset += 4
	record.entity_kind = ProtocolUtils.read_u8(bytes, offset)
	offset += 1
	offset += 1 # record flags
	offset += 2 # reserved

	record.position = Vector3(
		ProtocolUtils.read_float(bytes, offset),
		ProtocolUtils.read_float(bytes, offset + 4),
		ProtocolUtils.read_float(bytes, offset + 8)
	)
	offset += 12

	record.rotation = Quaternion(
		ProtocolUtils.read_float(bytes, offset),
		ProtocolUtils.read_float(bytes, offset + 4),
		ProtocolUtils.read_float(bytes, offset + 8),
		ProtocolUtils.read_float(bytes, offset + 12)
	).normalized()
	offset += 16

	return {
		"record": record,
		"offset": offset,
	}

static func _write_despawn_record(bytes: PackedByteArray, offset: int, entity: Variant) -> int:
	offset = ProtocolUtils.write_u32(bytes, offset, ProtocolUtils.get_int(entity, "entity_id", 0))
	offset = ProtocolUtils.write_u8(
		bytes,
		offset,
		ProtocolUtils.get_int(entity, "reason", DESPAWN_REASON_UNKNOWN)
	)
	offset = ProtocolUtils.write_u8(bytes, offset, 0)
	offset = ProtocolUtils.write_u16(bytes, offset, 0)
	return offset

static func _read_despawn_record(bytes: PackedByteArray, offset: int) -> Dictionary:
	var record = DespawnRecord.new()
	record.entity_id = ProtocolUtils.read_u32(bytes, offset)
	offset += 4
	record.reason = ProtocolUtils.read_u8(bytes, offset)
	offset += 1
	offset += 1 # record flags
	offset += 2 # reserved

	return {
		"record": record,
		"offset": offset,
	}
