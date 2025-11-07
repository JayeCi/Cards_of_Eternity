extends Control

signal deck_selected(selected_index: int)

@onready var hover: AudioStreamPlayer = $Sounds/Hover
@onready var click: AudioStreamPlayer = $Sounds/Click
@onready var deck_grid: GridContainer = $DeckGrid

var _decks: Array = []
var _float_offsets := {}
var _hovered_button: TextureButton = null
var _tweens := {}
var _selected_index := -1
var _locked_button: TextureButton = null

# --- Animation Constants ---
const FLOAT_AMPLITUDE := 2.0
const FLOAT_SPEED := 1.0
const PULSE_SCALE := 0.01
const PULSE_SPEED := 1.5

const HOVER_ZOOM := 1.15
const HOVER_MOVE_Y := -20.0
const HOVER_TWEEN_TIME := 0.25

const FADE_OUT_TIME := 3.0
const SLIDE_OUT_DISTANCE := 1000
const CENTER_TWEEN_TIME := 3.0


func _ready():
	visible = false
	for i in range(deck_grid.get_child_count()):
		var btn := deck_grid.get_child(i)
		if btn is TextureButton:
			btn.pressed.connect(_on_deck_pressed.bind(i))
			btn.mouse_entered.connect(_on_deck_hovered.bind(btn, true))
			btn.mouse_exited.connect(_on_deck_hovered.bind(btn, false))
			_float_offsets[btn] = randf() * TAU
	set_process(true)


func show_decks(deck_defs: Array):
	_decks = deck_defs
	visible = true


func _process(delta: float):
	# 🚫 Lock out all floating during deck select animation
	if _locked_button:
		return

	var time := Time.get_ticks_msec() / 1000.0
	for btn in deck_grid.get_children():
		if btn is TextureButton:
			var offset = _float_offsets.get(btn, 0.0)
			var base_pos = btn.get_meta("base_pos", btn.position)
			if not btn.has_meta("base_pos"):
				btn.set_meta("base_pos", base_pos)

			var is_hovered = (btn == _hovered_button)
			var float_y := sin(time * FLOAT_SPEED + offset) * FLOAT_AMPLITUDE
			btn.position.y = base_pos.y + float_y + (HOVER_MOVE_Y if is_hovered else 0.0)

			var pulse := 1.0 + sin(time * PULSE_SPEED + offset) * PULSE_SCALE
			btn.scale = btn.scale.lerp(Vector2.ONE * pulse * (HOVER_ZOOM if is_hovered else 1.0), 0.15)



# ------------------------------
# 🎯 Deck Selection
# ------------------------------
func _on_deck_pressed(index: int):
	if _selected_index >= 0:
		return

	click.play()
	_selected_index = index
	_hovered_button = null

	var chosen_btn: TextureButton = deck_grid.get_child(index)

	# 🚫 Immediately stop floating + hovering
	_locked_button = chosen_btn
	set_process(false)

	# Kill any active tween on this button
	if _tweens.has(chosen_btn):
		_tweens[chosen_btn].kill()

	# Store base position so nothing overwrites it
	chosen_btn.set_meta("base_pos", chosen_btn.position)

	# Get the center of the viewport
	var viewport_center := get_viewport_rect().size / 2.0
	var card_center_offset := chosen_btn.size / 2.0

	# Get local space center relative to grid
	var grid_global_pos := deck_grid.get_global_position()
	var center_pos := (viewport_center - grid_global_pos) - card_center_offset

	# --- Animate others out ---
	for i in range(deck_grid.get_child_count()):
		var btn := deck_grid.get_child(i)
		if btn is TextureButton and i != index:
			var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			var dir = sign(float(i) - float(index))
			var slide_x = dir * SLIDE_OUT_DISTANCE
			tween.parallel().tween_property(btn, "position:x", btn.position.x + slide_x, FADE_OUT_TIME)
			tween.parallel().tween_property(btn, "modulate:a", 0.0, FADE_OUT_TIME)
			tween.tween_callback(func(): btn.visible = false)

	## --- Center & emphasize chosen deck ---
	#var chosen_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#chosen_tween.tween_property(chosen_btn, "position", center_pos, CENTER_TWEEN_TIME)
	#chosen_tween.parallel().tween_property(chosen_btn, "scale", Vector2.ONE * 1.25, CENTER_TWEEN_TIME)
	#chosen_tween.parallel().tween_property(chosen_btn, "modulate", Color(1, 1, 1, 1), CENTER_TWEEN_TIME)
#
	#await chosen_tween.finished

	# ✅ Final lock — now resume process safely
	chosen_btn.position = center_pos
	chosen_btn.set_meta("base_pos", center_pos)
	chosen_btn.scale = Vector2.ONE * 1.25

	_locked_button = null
	set_process(true)

	await get_tree().create_timer(0.2).timeout
	emit_signal("deck_selected", index)



# ------------------------------
# ✨ Hover Interaction (Smooth)
# ------------------------------
func _on_deck_hovered(btn: TextureButton, hovering: bool):
	if _selected_index >= 0 or _locked_button:
		return

	hover.play()

	if _tweens.has(btn) and _tweens[btn] and _tweens[btn].is_running():
		_tweens[btn].kill()

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tweens[btn] = tween

	var base_pos = btn.get_meta("base_pos", btn.position)

	if hovering:
		_hovered_button = btn
		tween.tween_property(btn, "scale", Vector2.ONE * HOVER_ZOOM, HOVER_TWEEN_TIME)
		tween.tween_property(btn, "position:y", base_pos.y + HOVER_MOVE_Y, HOVER_TWEEN_TIME)
	else:
		if _hovered_button == btn:
			_hovered_button = null
		tween.tween_property(btn, "scale", Vector2.ONE, HOVER_TWEEN_TIME)
		tween.tween_property(btn, "position:y", base_pos.y, HOVER_TWEEN_TIME)
