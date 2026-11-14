extends Area2D
## Starts the bridge cutscene when the party steps onto the bridge (once).

@export_file("*.tscn") var cutscene := "res://scenes/cutscenes/BridgeCutscene.tscn"
@export var flag := "bridge_done"


func _ready() -> void:
	if GameManager.has_flag(flag):
		monitoring = false
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Party" or Dialogue.is_active:
		return
	set_deferred("monitoring", false)
	GameManager.go_to(cutscene)
