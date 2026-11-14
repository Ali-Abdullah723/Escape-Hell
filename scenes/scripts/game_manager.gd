extends Node
## Global game state (autoloaded as "GameManager").

## Story flags, e.g. "intro_done", "bridge_done".
var flags := {}

## Party member ids still with the party, left -> right.
var party := ["miria", "isaac", "jensen"]

## Id of the member sacrificed at the bridge ("" if none yet).
var sacrificed := ""

## Where the party should appear when the overworld loads: a Vector2, the name
## of a Marker2D in the overworld scene, or null for the scene default.
var overworld_spawn = null


func set_flag(flag: String, value = true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func sacrifice(member: String) -> void:
	sacrificed = member
	party.erase(member)


## Swap to another scene file (thin wrapper so transitions live in one place).
func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene_path)
