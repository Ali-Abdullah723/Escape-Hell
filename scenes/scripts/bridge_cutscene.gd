extends Control
## Bridge cutscene: the enemy demands a sacrifice to build the bridge.
## Dialogue comes from text files in res://dialogue/. Lines spoken by the enemy
## animate it; an optional [mood] in the file picks the animation, e.g.
##   Director [laugh]: Ha ha ha!

const ENEMY_ID := "director"

@export_file("*.txt") var intro_file := "res://dialogue/bridge_cutscene.txt"
## Aftermath file per choice; "%s" is replaced with the member id (miria/isaac/jensen).
@export var after_file_pattern := "res://dialogue/bridge_after_%s.txt"
@export_file("*.tscn") var return_scene := "res://node_2d.tscn"
## Name of the Marker2D in the overworld scene where the party appears afterwards.
@export var return_marker := "BridgeExit"

## Maps a dialogue [mood] to an enemy animation.
const MOOD_TO_ANIM := {
	"": "talk", "talk": "talk", "wide": "talk_wide", "shout": "talk_wide",
	"fast": "talk_fast", "laugh": "laugh", "whisper": "whisper", "sad": "sad",
	"hurt": "sad", "angry": "angry", "surprised": "surprised", "horror": "horror",
	"shock": "horror",
}

@onready var enemy: AnimatedSprite2D = $Enemy
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	var portrait := AtlasTexture.new()
	var idle_frame: AtlasTexture = enemy.sprite_frames.get_frame_texture("idle", 0)
	portrait.atlas = idle_frame.atlas
	portrait.region = idle_frame.region
	Dialogue.add_speaker(ENEMY_ID, "Director", portrait)

	_place_enemy()
	get_viewport().size_changed.connect(_place_enemy)
	enemy.play("idle")
	Dialogue.line_started.connect(_on_line_started)
	Dialogue.line_finished.connect(_on_line_finished)

	await _fade_to(0.0, 1.2)
	await Dialogue.play_file(intro_file)

	var members := ["miria", "isaac", "jensen"]
	var options := []
	for m in members:
		options.append("Sacrifice " + Dialogue.speakers[m]["name"])
	var pick := await Dialogue.choose(options, ENEMY_ID,
			"Choose. Whose flesh and bones will become my bridge?", "whisper")
	var chosen: String = members[pick]

	GameManager.sacrifice(chosen)
	GameManager.set_flag("bridge_done")
	enemy.play("horror")
	await Dialogue.play_file(after_file_pattern % chosen)

	await _fade_to(1.0, 1.0)
	GameManager.overworld_spawn = return_marker
	GameManager.go_to(return_scene)


func _place_enemy() -> void:
	var view := get_viewport_rect().size
	enemy.position = Vector2(view.x / 2.0, view.y * 0.36)
	enemy.scale = Vector2.ONE * (view.y / 330.0)


func _on_line_started(speaker_id: String, mood: String) -> void:
	if speaker_id == ENEMY_ID:
		enemy.play(MOOD_TO_ANIM.get(mood, "talk"))
	elif enemy.animation != "horror":
		enemy.play("idle")


func _on_line_finished(speaker_id: String) -> void:
	# Stop the mouth moving once the enemy's line is fully typed, unless it's a
	# one-shot reaction we want to keep on screen.
	if speaker_id == ENEMY_ID and enemy.animation in ["talk", "talk_wide", "talk_fast", "whisper"]:
		enemy.play("idle")


func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, seconds)
	await tween.finished
