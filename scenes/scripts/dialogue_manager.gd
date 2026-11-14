extends CanvasLayer
## Global dialogue box (autoloaded as "Dialogue").
##
## Usage from any script:
##   await Dialogue.play_file("res://dialogue/intro.txt")
##   await Dialogue.say("isaac", "Hello!")
##   await Dialogue.play_lines([["miria", "Hi."], ["jensen", "Yo."]])
##   var pick: int = await Dialogue.choose(["Yes", "No"], "director", "Well?")
##   Dialogue.add_speaker("director", "Director", some_texture)
##   Dialogue.add_highlight("escape", "orange")   # phrase shown bold + coloured
##
## Text file format (one line per message):
##   Speaker Name: what they say
##   Speaker Name [mood]: what they say      <- optional mood, e.g. [laugh]
##   # comment lines and blank lines are ignored
## Speaker names are matched case-insensitively against ids and display names.
## The mood is passed to the `line_started` signal so scenes can animate.

signal started
signal finished
## Emitted when each line begins: speaker id ("" if unknown) and mood ("" if none).
signal line_started(speaker_id: String, mood: String)
## Emitted when a line has been fully shown and the player has advanced.
signal line_finished(speaker_id: String)

@export var chars_per_second := 40.0

## Phrases shown bold and coloured wherever they appear (case-insensitive).
## phrase -> colour name or hex, e.g. {"bounce back": "red"}
@export var highlight_words := {"bounce back": "red"}

## id -> { "name": String, "portrait": Texture2D }
var speakers := {
	"miria": {"name": "Miria", "portrait": preload("res://assets/miria.png")},
	"isaac": {"name": "Isaac", "portrait": preload("res://assets/isaac.png")},
	"jensen": {"name": "Jensen Huang", "portrait": preload("res://assets/Jensen huang.png")},
}

var is_active := false

var _panel: PanelContainer
var _portrait: TextureRect
var _name_label: Label
var _text_label: RichTextLabel
var _hint: Label
var _choice_panel: PanelContainer
var _choice_list: VBoxContainer
var _advance_requested := false
var _depth := 0

signal _choice_made(index: int)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()
	_choice_panel.hide()


# ---------------------------------------------------------------- public API

## Register (or replace) a speaker so it can be used in files / say().
func add_speaker(id: String, display_name: String, portrait: Texture2D = null) -> void:
	speakers[id.to_lower()] = {"name": display_name, "portrait": portrait}


## Make a phrase show bold in the given colour in every line.
func add_highlight(phrase: String, color := "red") -> void:
	highlight_words[phrase] = color


## Show a single message and wait for the player to advance.
func say(speaker: String, text: String, mood := "") -> void:
	_open()
	await _show_line(speaker, text, mood)
	_close()


## Play a list of [speaker, text] or [speaker, text, mood] entries in order.
func play_lines(lines: Array) -> void:
	if lines.is_empty():
		return
	_open()
	for line in lines:
		await _show_line(line[0], line[1], line[2] if line.size() > 2 else "")
	_close()


## Load a dialogue text file and play it.
func play_file(path: String) -> void:
	await play_lines(load_file(path))


## Show a question with buttons; returns the index of the chosen option.
## Use arrow keys + Enter, or the mouse.
func choose(options: Array, speaker := "", prompt := "", mood := "") -> int:
	_open()
	if prompt != "":
		await _show_line(speaker, prompt, mood, false)
	for child in _choice_list.get_children():
		child.queue_free()
	for i in options.size():
		var button := Button.new()
		button.text = str(options[i])
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(func(): _choice_made.emit(i))
		_choice_list.add_child(button)
	_choice_panel.show()
	_hint.hide()
	(_choice_list.get_child(0) as Button).grab_focus.call_deferred()
	var picked: int = await _choice_made
	_choice_panel.hide()
	_close()
	return picked


## Parse a dialogue text file into [speaker, text, mood] entries.
func load_file(path: String) -> Array:
	var lines := []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Dialogue: cannot open %s" % path)
		return lines
	while not file.eof_reached():
		var raw := file.get_line().strip_edges()
		if raw.is_empty() or raw.begins_with("#"):
			continue
		var colon := raw.find(":")
		if colon == -1:
			push_warning("Dialogue: no 'Speaker:' in line: %s" % raw)
			lines.append(["", raw, ""])
			continue
		var who := raw.left(colon).strip_edges()
		var mood := ""
		var bracket := who.find("[")
		if bracket != -1 and who.ends_with("]"):
			mood = who.substr(bracket + 1, who.length() - bracket - 2).strip_edges().to_lower()
			who = who.left(bracket).strip_edges()
		lines.append([who, raw.substr(colon + 1).strip_edges(), mood])
	return lines


# ---------------------------------------------------------------- internals

func _open() -> void:
	_depth += 1
	if _depth == 1:
		is_active = true
		_panel.show()
		started.emit()


func _close() -> void:
	_depth -= 1
	if _depth == 0:
		_panel.hide()
		is_active = false
		finished.emit()


## Returns the speaker id for a name/id, or "" if unknown.
func _speaker_id(speaker: String) -> String:
	var key := speaker.to_lower()
	if speakers.has(key):
		return key
	for id in speakers:
		if speakers[id]["name"].to_lower() == key:
			return id
	return ""


func _show_line(speaker: String, text: String, mood := "", wait_for_advance := true) -> void:
	var id := _speaker_id(speaker)
	var info: Dictionary = speakers[id] if id != "" else {"name": speaker, "portrait": null}
	_name_label.text = info["name"]
	_name_label.visible = info["name"] != ""
	_portrait.texture = info["portrait"]
	_portrait.visible = info["portrait"] != null
	_text_label.text = _apply_highlights(text)
	_text_label.visible_characters = 0
	_hint.hide()
	line_started.emit(id, mood)

	# Typewriter effect; pressing accept fills the line instantly.
	_advance_requested = false
	var total := _text_label.get_total_character_count()
	var shown := 0.0
	while shown < total and not _advance_requested:
		await get_tree().process_frame
		shown += chars_per_second * get_process_delta_time()
		_text_label.visible_characters = int(shown)
	_text_label.visible_characters = -1
	line_finished.emit(id)
	if not wait_for_advance:
		return

	_hint.show()
	_advance_requested = false
	while not _advance_requested:
		await get_tree().process_frame


func _apply_highlights(text: String) -> String:
	for phrase in highlight_words:
		var regex := RegEx.create_from_string("(?i)" + _regex_escape(phrase))
		text = regex.sub(text, "[b][color=%s]$0[/color][/b]" % highlight_words[phrase], true)
	return text


func _regex_escape(s: String) -> String:
	var out := ""
	for c in s:
		out += ("\\" + c) if c in ".^$*+?()[]{}|\\" else c
	return out


func _unhandled_input(event: InputEvent) -> void:
	if is_active and not _choice_panel.visible and event.is_action_pressed("ui_accept"):
		_advance_requested = true
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.92)
	style.border_color = Color(0.92, 0.92, 0.92)
	style.set_border_width_all(3)
	style.set_content_margin_all(12)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 24
	_panel.offset_right = -24
	_panel.offset_top = -180
	_panel.offset_bottom = -24
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(130, 130)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	column.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 22)
	_text_label.add_theme_font_size_override("bold_font_size", 22)
	column.add_child(_text_label)

	_hint = Label.new()
	_hint.text = "▼ Enter / Space"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	column.add_child(_hint)

	# Choice buttons sit just above the dialogue box, on the right.
	_choice_panel = PanelContainer.new()
	_choice_panel.anchor_left = 1.0
	_choice_panel.anchor_right = 1.0
	_choice_panel.anchor_top = 1.0
	_choice_panel.anchor_bottom = 1.0
	_choice_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choice_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice_panel.offset_right = -24
	_choice_panel.offset_bottom = -192
	_choice_panel.add_theme_stylebox_override("panel", style)
	add_child(_choice_panel)

	_choice_list = VBoxContainer.new()
	_choice_list.add_theme_constant_override("separation", 6)
	_choice_panel.add_child(_choice_list)
