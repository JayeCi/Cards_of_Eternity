# Professional Deck Selection Screen
extends Control

signal deck_selected(selected_index: int)

@onready var deck_container: HBoxContainer = $DeckContainer
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel
@onready var hover_sound: AudioStreamPlayer = $Sounds/Hover
@onready var click_sound: AudioStreamPlayer = $Sounds/Click

var _decks: Array = []
var _deck_panels: Array[PanelContainer] = []
var _selected_index := -1
var _is_selecting := false

# Deck art paths
const DECK_ART_PATHS := {
	0: "res://World/MAP/FIREDECK.png",
	1: "res://World/MAP/earthdeck.png",
	2: "res://World/MAP/winddeck.png",
	3: "res://World/MAP/waterdeck.png"
}

# Deck information
const DECK_INFO := {
	0: {
		"name": "Inferno's Fury",
		"element": "Fire",
		"description": "Aggressive offense with burning damage over time",
		"color": Color("FF6B35"),
		"particle_color": Color("FF4500")
	},
	1: {
		"name": "Stone's Endurance",
		"element": "Earth",
		"description": "Defensive tactics with terrain control",
		"color": Color("8B7355"),
		"particle_color": Color("CD853F")
	},
	2: {
		"name": "Tempest's Grace",
		"element": "Wind",
		"description": "Swift mobility and evasive maneuvers",
		"color": Color("87CEEB"),
		"particle_color": Color("E0FFFF")
	},
	3: {
		"name": "Tidal Wisdom",
		"element": "Water",
		"description": "Adaptive strategy with healing support",
		"color": Color("4682B4"),
		"particle_color": Color("00CED1")
	}
}


func _ready():
	visible = false
	modulate.a = 0.0


func show_decks(deck_defs: Array):
	_decks = deck_defs
	visible = true
	_create_deck_panels()
	_animate_entrance()


func _create_deck_panels():
	# Clear existing panels
	for child in deck_container.get_children():
		child.queue_free()
	_deck_panels.clear()

	# Create professional deck cards
	for i in range(_decks.size()):
		var panel = _create_deck_panel(i)
		deck_container.add_child(panel)
		_deck_panels.append(panel)


func _create_deck_panel(index: int) -> PanelContainer:
	var info = DECK_INFO[index]

	# Main panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 400)
	panel.modulate.a = 0.0  # Start invisible for entrance animation

	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = info.color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

	# Content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Element icon/header
	var header = ColorRect.new()
	header.color = info.color
	header.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(header)

	var element_label = Label.new()
	element_label.text = info.element.to_upper()
	element_label.set_anchors_preset(PRESET_FULL_RECT)
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	element_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	element_label.add_theme_font_size_override("font_size", 32)
	element_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(element_label)

	# Deck name
	var name_label = Label.new()
	name_label.text = info.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", info.color)
	vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = info.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Select button
	var button = Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(0, 50)
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = info.color
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_style)
	button.add_theme_stylebox_override("pressed", button_style)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.pressed.connect(_on_deck_selected.bind(index))
	button.mouse_entered.connect(_on_panel_hovered.bind(panel, true))
	button.mouse_exited.connect(_on_panel_hovered.bind(panel, false))
	vbox.add_child(button)

	# Add mouse detection to panel itself
	panel.mouse_entered.connect(_on_panel_hovered.bind(panel, true))
	panel.mouse_exited.connect(_on_panel_hovered.bind(panel, false))

	return panel


func _animate_entrance():
	# Fade in title/subtitle
	var title_tween = create_tween()
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.8)

	var subtitle_tween = create_tween()
	subtitle_tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.8).set_delay(0.2)

	# Fade in screen
	var screen_tween = create_tween()
	screen_tween.tween_property(self, "modulate:a", 1.0, 0.6)

	# Stagger deck panel entrance
	await get_tree().create_timer(0.5).timeout

	for i in range(_deck_panels.size()):
		var panel = _deck_panels[i]
		var delay = i * 0.15

		# Slide up and fade in
		panel.position.y = 50
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position:y", 0, 0.6).set_delay(delay)
		tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.6).set_delay(delay)


func _on_panel_hovered(panel: PanelContainer, hovered: bool):
	if _is_selecting:
		return

	if hovered:
		hover_sound.play()

	# Smooth glow effect
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if hovered:
		tween.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.2)
		# Add subtle glow by brightening border
		var style = panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			tween.parallel().tween_property(style, "border_color", style.border_color.lightened(0.3), 0.2)
	else:
		tween.tween_property(panel, "scale", Vector2.ONE, 0.2)
		var style = panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var index = _deck_panels.find(panel)
			if index >= 0:
				tween.parallel().tween_property(style, "border_color", DECK_INFO[index].color, 0.2)


func _on_deck_selected(index: int):
	if _is_selecting:
		return

	_is_selecting = true
	_selected_index = index
	click_sound.play()

	# Fade out non-selected panels
	for i in range(_deck_panels.size()):
		if i != index:
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.tween_property(_deck_panels[i], "modulate:a", 0.0, 0.5)
			tween.parallel().tween_property(_deck_panels[i], "scale", Vector2(0.8, 0.8), 0.5)

	# Fade out title/subtitle
	var title_tween = create_tween()
	title_tween.tween_property(title_label, "modulate:a", 0.0, 0.4)
	title_tween.parallel().tween_property(subtitle_label, "modulate:a", 0.0, 0.4)

	await get_tree().create_timer(0.6).timeout

	# Get selected panel and prepare for centering
	var selected_panel = _deck_panels[index]

	# Store current global position before reparenting
	var current_global_pos = selected_panel.global_position
	var panel_size = selected_panel.size

	# Reparent to root to escape container layout constraints
	var original_parent = selected_panel.get_parent()
	original_parent.remove_child(selected_panel)
	add_child(selected_panel)

	# Restore global position after reparenting
	selected_panel.global_position = current_global_pos

	# Set pivot to center for symmetric scaling
	selected_panel.pivot_offset = panel_size / 2.0

	# Calculate true center position (accounting for pivot)
	var viewport_center = get_viewport_rect().size / 2.0
	var centered_position = viewport_center - (panel_size / 2.0)

	# Smooth move to center with scale up
	var center_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	center_tween.tween_property(selected_panel, "global_position", centered_position, 0.8)
	center_tween.tween_property(selected_panel, "scale", Vector2(1.3, 1.3), 0.8)

	await center_tween.finished
	await get_tree().create_timer(0.3).timeout

	# Flip animation and show deck art
	await _animate_flip_to_deck_art(selected_panel, index)

	await get_tree().create_timer(1.0).timeout
	emit_signal("deck_selected", index)


func _animate_flip_to_deck_art(panel: PanelContainer, index: int):
	# Store the current center position before any scaling
	var viewport_center = get_viewport_rect().size / 2.0
	var panel_center = panel.global_position + (panel.size / 2.0)

	# Create deck art texture rect
	var deck_art = TextureRect.new()
	deck_art.texture = load(DECK_ART_PATHS[index])
	deck_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	deck_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	deck_art.modulate.a = 0.0
	deck_art.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add to panel (behind existing content initially)
	panel.add_child(deck_art)
	panel.move_child(deck_art, 0)

	# Professional flip animation - scale X to 0, swap content, scale back
	# Part 1: Flip out (shrink horizontally to center)
	var flip_out = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Scale down X while keeping Y constant for clean flip effect
	flip_out.tween_property(panel, "scale:x", 0.0, 0.35)

	# Maintain center position during scale (compensate for pivot)
	var new_pos_during_flip = viewport_center - (panel.size * Vector2(0, 1.3) / 2.0)
	flip_out.tween_property(panel, "global_position:y", new_pos_during_flip.y, 0.35)

	await flip_out.finished

	# Swap content at the thinnest point of flip
	for child in panel.get_children():
		if child != deck_art:
			child.visible = false
	deck_art.modulate.a = 1.0

	# Part 2: Flip in (expand horizontally from center)
	var flip_in = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Scale back to 1.3
	flip_in.tween_property(panel, "scale:x", 1.3, 0.35)

	# Restore centered position
	var final_centered_pos = viewport_center - (panel.size * 1.3 / 2.0)
	flip_in.tween_property(panel, "global_position", final_centered_pos, 0.35)

	await flip_in.finished

	# Final position lock - ensure absolutely perfect centering
	panel.global_position = viewport_center - (panel.size * 1.3 / 2.0)
