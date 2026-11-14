extends CharacterBody2D
## Moves the whole 3-character party as one body (arrow keys via ui_* actions).
## Each AnimatedSprite2D child has idle_<dir> and walk_<dir> animations
## for dir in down / left / right / up.

@export var speed := 80.0

var facing := "down"


func _ready() -> void:
	_play("idle")


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if not Dialogue.is_active:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

	if direction == Vector2.ZERO:
		_play("idle")
		return
	# Pick the dominant axis so diagonals show a sensible facing.
	if absf(direction.x) > absf(direction.y):
		facing = "right" if direction.x > 0 else "left"
	else:
		facing = "down" if direction.y > 0 else "up"
	_play("walk")


func _play(state: String) -> void:
	var anim := "%s_%s" % [state, facing]
	for child in get_children():
		if child is AnimatedSprite2D and child.animation != anim:
			child.play(anim)


## Party member id -> sprite node name.
const MEMBER_NODES := {"miria": "Left", "isaac": "Center", "jensen": "Right"}


## Horizontal distance between neighbouring party members, in pixels.
@export var member_spacing := 16.0
## Extra hitbox width beyond the members themselves (3 members * 16 - 4 = 44).
@export var hitbox_padding := -4.0


## Hide a member's sprite (e.g. after the bridge sacrifice), then pull the
## remaining members together and shrink the hitbox to fit them.
func remove_member(member: String) -> void:
	var sprite := get_node_or_null(MEMBER_NODES.get(member, "")) as AnimatedSprite2D
	if sprite == null:
		return
	sprite.visible = false
	_regroup()


## Re-centre the visible members around the party origin and resize hitboxes.
func _regroup() -> void:
	var members: Array[AnimatedSprite2D] = []
	for node_name in ["Left", "Center", "Right"]:
		var s := get_node_or_null(node_name) as AnimatedSprite2D
		if s and s.visible:
			members.append(s)
	if members.is_empty():
		return

	var start := -member_spacing * (members.size() - 1) / 2.0
	for i in members.size():
		members[i].position.x = start + member_spacing * i

	# The camera lives on Center; offset it so it stays on the party's middle
	# even if Center moved or was hidden.
	var cam := get_node_or_null("Center/Camera2D") as Camera2D
	if cam:
		cam.position.x = -$Center.position.x
		cam.make_current()

	var width := member_spacing * members.size() + hitbox_padding
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			# Duplicate so we don't modify the shared resource on disk.
			var rect: RectangleShape2D = child.shape.duplicate()
			rect.size.x = width
			child.shape = rect
			child.position.x = 0.0
