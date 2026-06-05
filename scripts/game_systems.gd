extends Node

@onready var entities: Node = %Entities
@onready var ticker: Ticker = %Ticker

func _ready() -> void:
	ticker.tick.connect(_on_tick)

func _on_tick(n: int, delta: float) -> void:
	pass # TODO: gather input, process movement, send stuff to server.
