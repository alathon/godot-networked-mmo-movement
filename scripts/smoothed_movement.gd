extends Node

# TODO: lerp movement between last body position and current body position, so
# we get per-frame smooth movement even though PlayerEntity is moving every 50ms.

@export var model: Node3D
@export var body: PhysicsBody
