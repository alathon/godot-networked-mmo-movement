class_name RemoteEntity
extends BaseEntity

@onready var body: RemoteBody = %Body
@onready var interpolation_buffer: RemoteInterpolationBuffer = %RemoteInterpolationBuffer

func get_rid() -> RID:
	return body.get_rid()

func is_alive():
	return true

func get_body():
	return body

func push_movement_snapshot(snapshot: Dictionary) -> void:
	interpolation_buffer.push_movement_snapshot(snapshot)
