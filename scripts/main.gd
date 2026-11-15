extends Node3D
## Entry point. Everything (world, player, UI) is built in code by the Game autoload,
## so the project has no binary assets and every system can be read as text.

func _ready() -> void:
	Game.boot(self)
