extends Node2D
## Main overworld scene: plays the opening conversation the first time,
## and applies story results (spawn point, sacrificed member) when returning.

@export_file("*.txt") var intro_dialogue := "res://dialogue/intro.txt"

@onready var party: CharacterBody2D = $Party


func _ready() -> void:
	# overworld_spawn can be a Vector2 or the name of a Marker2D in this scene.
	var spawn = GameManager.overworld_spawn
	if spawn is String and has_node(spawn):
		party.position = get_node(spawn).position
	elif spawn is Vector2:
		party.position = spawn
	GameManager.overworld_spawn = null
	if GameManager.sacrificed != "":
		party.remove_member(GameManager.sacrificed)

	if not GameManager.has_flag("intro_done"):
		GameManager.set_flag("intro_done")
		await Dialogue.play_file(intro_dialogue)
