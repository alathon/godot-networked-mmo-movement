class_name RemoteEntity
extends BaseEntity

@onready var body: RemoteBody = %Body
@onready var model: Node3D = %Model

func get_rid() -> RID:
	return body.get_rid()

func is_alive():
	return true

func get_body():
	return body

func simulate(delta: float) -> void:
	simulate_remote_tick(delta)

func simulate_remote_tick(_delta: float) -> void:
	pass
