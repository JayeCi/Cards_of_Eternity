extends Control

@onready var main_panel := $CollectionPanel/ScrollContainer/GridContainer
@onready var deck_collection_grid: GridContainer = $DeckPanel/Panel/Collection/ScrollContainer/CollectionGrid
@onready var deck_grid: GridContainer = $DeckPanel/Deck/ScrollContainer/DeckGrid
@onready var sfx_action_beep: AudioStreamPlayer = $ActionBeep
@onready var sort_button: Button = $Toolbar/ButtonRow2/SortButton
@onready var shadow_ball: AnimatedSprite2D = $LeftPanel/CardName/ShadowBall
@onready var water_ball: AnimatedSprite2D = $LeftPanel/CardName/WaterBall
@onready var fire_ball: AnimatedSprite2D = $LeftPanel/CardName/FireBall
@onready var wind_ball: AnimatedSprite2D = $LeftPanel/CardName/WindBall
@onready var earth_ball: AnimatedSprite2D = $LeftPanel/CardName/EarthBall
@onready var deck_count: Label = $DeckPanel/Deck/Panel/DeckLabel/MarginContainer/DeckCount
@onready var tutorial_popups: Panel = $Tutorial_Popups
@onready var continue_btn: Button = $Tutorial_Popups/Tutorial_Panel/Tutorial_VBox/Tutorial_Continue_Button



var _sort_mode := "name"
var _sort_ascending := true

var tutorial_can_continue := false

var left_panel: Control
var card_name_label: Label
var rarity_label: Label
var cost_label: Label
var atk_label: Label
var def_label: Label
var subtype_label: Label
var abilities_label: Label
var ability_desc_label: Label
var description_label: Label
var art_texture_rect: TextureRect
var art_border: TextureRect
var displayed_cards := {}
var player = null
var _elem_to_ball := {}
@onready var tutorial_label: RichTextLabel = $Tutorial_Popups/Tutorial_Panel/Tutorial_VBox/MarginContainer/Tutorial_Text

	
@onready var collection_panel: Panel = $CollectionPanel
@onready var leader_panel: Panel = $LeaderPanel
@onready var deck_panel: Panel = $DeckPanel
@onready var main_panel_label: Label = $Toolbar/MainPanelLabel

var selected_card: CardData = null

func _ready():
	if sort_button:
		sort_button.pressed.connect(_on_sort_button_pressed)

	# 🧩 Setup layout references
	left_panel = get_node_or_null("LeftPanel")
	if not left_panel:
		push_error("[CollectionGUI] ❌ LeftPanel not found.")
		return

	# 🧩 Populate existing collection cards
	_populate_existing_cards()
	_refresh_deck_grid()
	
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("[CollectionGUI] ⚠️ Player group not found.")
	else:
		print("[CollectionGUI] ✅ Player found:", player.name)

	# 🔗 Connect collection singleton signals
	if not CardCollection.is_connected("card_added", Callable(self, "_on_card_added_signal")):
		CardCollection.connect("card_added", Callable(self, "_on_card_added_signal"))
	if not CardCollection.is_connected("card_count_changed", Callable(self, "_on_card_count_changed")):
		CardCollection.connect("card_count_changed", Callable(self, "_on_card_count_changed"))
		
		_elem_to_ball = {
		"fire":   fire_ball,
		"water":  water_ball,
		"earth":  earth_ball,
		"wind":   wind_ball,
		"shadow": shadow_ball,
	}
	_hide_all_element_balls()
	# 🧾 Cache label nodes
	card_name_label = left_panel.get_node_or_null("CardName/Name")
	rarity_label = left_panel.get_node_or_null("CardName/Rarity")
	cost_label = left_panel.get_node_or_null("CardName/Cost/CostLabel")
	atk_label = left_panel.get_node_or_null("Panel/Border/HBoxContainer/ATK")
	def_label = left_panel.get_node_or_null("Panel/Border/HBoxContainer/DEF")
	subtype_label = left_panel.get_node_or_null("ScrollContainer/VBoxContainer/Subtype")
	abilities_label = left_panel.get_node_or_null("ScrollContainer/VBoxContainer/Abilities")
	ability_desc_label = left_panel.get_node_or_null("ScrollContainer/VBoxContainer/Ability Description")
	description_label = left_panel.get_node_or_null("ScrollContainer/VBoxContainer/Description")
	art_texture_rect = left_panel.get_node_or_null("Panel/Art")
	art_border = left_panel.get_node_or_null("Panel/Border")
	_clear_left_panel()

	print("[CollectionGUI] ✅ Ready – drag/drop initialized.")
	
	tutorial_popups.visible = true
	tutorial_label.clear()
	tutorial_label.bbcode_enabled = true

	tutorial_label.append_text("[center][b]Welcome to Cards of Eternity![/b][/center]\n\n")
	tutorial_label.append_text("This is the [b]Card Collection UI[/b].\n")
	tutorial_label.append_text("Here you can view all of the cards you have collected, inspect their details, and see which cards are currently in your deck.\n\n")
	tutorial_label.append_text("[color=yellow]• Hover[/color] a card to inspect it in detail.\n")
	tutorial_label.append_text("[color=green]• Click[/color] a card to add or remove it from your deck.\n\n")
	tutorial_label.append_text("When you're ready, click the [b]\"C\"[/b] on the toolbar to go to your full collection list.")
	tutorial_can_continue = false
	_unlock_tutorial_continue()

	var tween = create_tween()
	tween.tween_property(tutorial_label, "visible_characters", tutorial_label.get_total_character_count(), 1.75)

# ==========================================================
# 🖱️ CARD INTERACTION (Click + Hover)
# ==========================================================
func _on_card_hovered(card_data: CardData):
	if selected_card and selected_card == card_data:
		return
	_update_left_panel(card_data, true)

func _on_card_unhovered(card_data: CardData = null):
	if selected_card:
		_update_left_panel(selected_card)
	else:
		_clear_left_panel()

func _on_card_clicked(event: InputEvent, card_ui):
		# 🛑 REFUSE collection→deck moves if deck is full
	if deck_grid.get_child_count() >= 10:
		sfx_action_beep.play()
		print("[DeckBuilder] 🚫 Deck full. Cannot add more.")
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sfx_action_beep:
			sfx_action_beep.play()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var parent_grid = card_ui.get_parent()

		# --- Move from Collection to Deck ---
		if deck_collection_grid.is_ancestor_of(card_ui) or parent_grid == deck_collection_grid:
			if _move_card_to_deck(card_ui.card_data):
				card_ui.queue_free()
			else:
				print("[DeckBuilder] ❌ Add failed. Not destroying UI.")

			print("[DeckBuilder] ➕ Moved", card_ui.card_data.name, "→ Deck")

		# --- Move from Deck to Collection ---
		elif deck_grid.is_ancestor_of(card_ui) or parent_grid == deck_grid:
			_move_card_to_collection(card_ui.card_data)
			card_ui.queue_free()
			print("[DeckBuilder] ↩️ Moved", card_ui.card_data.name, "→ Collection")

		selected_card = card_ui.card_data
		_update_left_panel(selected_card)

func _move_card_to_deck(card_data: CardData) -> bool:
	if deck_grid.get_child_count() >= 10:
		return false

	if not DeckManager.add(card_data.id):
		return false

	_refresh_deck_grid()
	_refresh_collection_counts()
	_update_deck_count()
	return true


func _on_card_count_changed(card_id: String, new_count: int) -> void:
	# Loop over both main collection and deck collection grids
	for grid in [main_panel, deck_collection_grid]:
		for child in grid.get_children():
			if "card_data" in child and child.card_data and child.card_data.id == card_id:
				if child.has_method("set_quantity"):
					child.set_quantity(new_count)
					print("[CollectionGUI] 🔄 Updated quantity for ", card_id, " → ", new_count, " Total")

func _move_card_to_collection(card_data: CardData):
	if not DeckManager.remove_one(card_data.id):
		print("[DeckBuilder] ⚠️ Not in deck:", card_data.name)
		return

	if not displayed_cards.has(card_data.id):
		_add_card_to_gui(card_data)
	else:
		_refresh_collection_counts()

	_refresh_deck_grid()

	var card_ui_scene := preload("res://UI/CardUI.tscn")
	var deck_card_ui: Control = card_ui_scene.instantiate()
	deck_card_ui.card_data = card_data
	deck_card_ui.refresh()
	deck_collection_grid.add_child(deck_card_ui)

	deck_card_ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(deck_card_ui))
	deck_card_ui.connect("request_show_zoom", Callable(self, "_on_card_hovered"))
	deck_card_ui.connect("request_hide_zoom", Callable(self, "_on_card_unhovered"))

	print("[DeckBuilder] 🔁 Returned", card_data.name, "to deck collection grid")

	# ✅ FIX: update deck count after removing
	_update_deck_count()

func _refresh_collection_counts():
	for child in main_panel.get_children():
		if "card_data" in child and child.card_data:
			var left := DeckManager.remaining_available(child.card_data.id)
			if child.has_method("set_quantity"):
				child.set_quantity(left)  # show true remaining

func _update_deck_count() -> void:
	await get_tree().process_frame

	var ids := DeckManager.get_ids()
	var count := ids.size()
	deck_count.text = "%d / 10" % count

	if count >= 10:
		deck_count.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif count >= 7:
		deck_count.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	else:
		deck_count.add_theme_color_override("font_color", Color(0.8, 1, 0.8))

	# 👉 Trigger Tutorial Stage 3
	if count == 5 and Globals.tutorial_stage == 2:
		_show_tutorial_stage_3()
		Globals.tutorial_stage = 3

func _refresh_deck_grid():
	for c in deck_grid.get_children():
		c.queue_free()

	var card_ui_scene := preload("res://UI/CardUI.tscn")
	for id in DeckManager.get_ids():
		var data := CardCollection.get_card_data(id)
		if not data:
			continue
		var ui: Control = card_ui_scene.instantiate()
		ui.card_data = data
		ui.refresh()
		deck_grid.add_child(ui)
		ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(ui))

	# ✅ update label after rebuilding
	_update_deck_count()

# ==========================================================
# 🧩 ADD/REMOVE CARDS
# ==========================================================
func _populate_existing_cards():
	for id in CardCollection.get_all_cardss():
		var data = CardCollection.get_card_data(id)
		if data:
			_add_card_to_gui(data)

func _add_card_to_gui(card_data: CardData):
	if not card_data or displayed_cards.has(card_data.id):
		return
	displayed_cards[card_data.id] = true

	var card_ui_scene := preload("res://UI/CardUI.tscn")

	var card_ui: Control = card_ui_scene.instantiate()
	card_ui.card_data = card_data
	card_ui.refresh()
	
		# show remaining copies available to add into deck
	if card_ui.has_method("set_quantity"):
		card_ui.set_quantity(DeckManager.remaining_available(card_data.id))
		
	main_panel.add_child(card_ui)

	# Connect hover/click
	card_ui.connect("request_show_zoom", Callable(self, "_on_card_hovered"))
	card_ui.connect("request_hide_zoom", Callable(self, "_on_card_unhovered"))
	card_ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(card_ui))
	card_ui.connect("request_return_to_collection", Callable(self, "_on_card_return_requested"))

	# Mirror in deck builder’s collection grid
	var deck_card_ui: Control = card_ui_scene.instantiate()
	deck_card_ui.card_data = card_data
	deck_card_ui.refresh()
	deck_collection_grid.add_child(deck_card_ui)

	# 🟢 Make these clickable too
	deck_card_ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(deck_card_ui))
	deck_card_ui.connect("request_show_zoom", Callable(self, "_on_card_hovered"))
	deck_card_ui.connect("request_hide_zoom", Callable(self, "_on_card_unhovered"))


func _on_card_added_signal(card: CardData, count: int):
	if displayed_cards.has(card.id):
		return
	print("[CollectionGUI] ➕ Card added:", card.name, " x ", count)
	_add_card_to_gui(card)

func _on_card_return_requested(card_data: CardData):
	if not card_data:
		return

	var card_ui_scene := preload("res://UI/CardUI.tscn")
	var new_card_ui: Control = card_ui_scene.instantiate()
	new_card_ui.card_data = card_data
	new_card_ui.refresh()
	deck_collection_grid.add_child(new_card_ui)

	print("[DeckBuilder] ↩️ Returned", card_data.name, "to collection")

	for child in deck_grid.get_children():
		if child.card_data and child.card_data.id == card_data.id:
			child.queue_free()
			print("[DeckBuilder] ❌ Removed", card_data.name, "from deck grid")
			break

# ==========================================================
# 🧾 LEFT PANEL UPDATES
# ==========================================================
func _update_left_panel(card_data: CardData, temporary := false):
	if not card_data:
		return
	if card_name_label: card_name_label.text = card_data.name
	if rarity_label: rarity_label.text = str(card_data.rarity).capitalize()
	if cost_label: cost_label.text = str(card_data.cost)
	if atk_label: atk_label.text = str(card_data.atk)
	if def_label: def_label.text = str(card_data.def)
	if subtype_label:
		subtype_label.text = " / ".join(card_data.types) if card_data.types.size() > 0 else "-"
	if abilities_label: abilities_label.text = card_data.get_ability_name()
	if ability_desc_label: ability_desc_label.text = card_data.get_ability_description()
	if description_label: description_label.text = card_data.description
	if art_texture_rect and card_data.art:
		art_texture_rect.texture = card_data.art
	if art_border: art_border.visible = true
	_update_left_panel_element(card_data)   # <- add this
	
func _clear_left_panel():
	for label in [card_name_label, rarity_label, cost_label, atk_label, def_label, subtype_label, abilities_label, ability_desc_label, description_label]:
		if label:
			label.text = ""
	if art_texture_rect:
		art_texture_rect.texture = null
	art_border.visible = false
	_hide_all_element_balls()   
	
func _hide_all_element_balls() -> void:
	for node in [_elem_to_ball.get("fire"), _elem_to_ball.get("water"), _elem_to_ball.get("earth"), _elem_to_ball.get("wind"), _elem_to_ball.get("shadow")]:
		if node:
			node.visible = false
			if node.sprite_frames:
				node.stop()

func _update_left_panel_element(cd: CardData) -> void:
	_hide_all_element_balls()
	if cd == null:
		return
	var key := _resolve_element_key(cd)
	if key == "":
		return
	var ball: AnimatedSprite2D = _elem_to_ball.get(key, null)
	if ball:
		ball.visible = true
		if ball.sprite_frames:
			if ball.sprite_frames.has_animation("default"):
				ball.play("default")
			else:
				var names := ball.sprite_frames.get_animation_names()
				if names.size() > 0:
					ball.play(names[0])

func _resolve_element_key(cd: CardData) -> String:
	var e = null

	# 1) direct property
	if cd.has_method("get"):
		e = cd.get("element")

	# 2) custom getter
	if e == null and cd.has_method("get_element"):
		e = cd.get_element()

	# 3) fallback: search in types
	if e == null and cd.has_method("get"):
		var types = cd.get("types")
		if types is Array:
			for t in types:
				var tl := str(t).to_lower()
				if _elem_to_ball.has(tl):
					e = tl
					break

	if e == null:
		return ""

	# Normalize enum or string
	if typeof(e) == TYPE_INT:
		var enum_map := { 0:"fire", 1:"water", 2:"earth", 3:"wind", 4:"shadow" }
		return enum_map.get(e, "")
	else:
		return str(e).to_lower()

# ==========================================================
# 🔢 SORTING
# ==========================================================
func _on_sort_button_pressed() -> void:
	# Cycle sort mode each click
	match _sort_mode:
		"name":
			_sort_mode = "rarity"
		"rarity":
			_sort_mode = "cost"
		"cost":
			_sort_mode = "name"
			_sort_ascending = not _sort_ascending  # flip direction at end

	sort_button.text = "Sort: %s %s" % [
		_sort_mode.capitalize(),
		"↑" if _sort_ascending else "↓"
	]

	_refresh_sorted_collection()


func _refresh_sorted_collection() -> void:
	var all_cards: Array = []
	for child in main_panel.get_children():
		if "card_data" in child:
			all_cards.append(child.card_data)

	# Sort based on selected mode
	all_cards.sort_custom(Callable(self, "_compare_cards"))

	# Clear all existing card nodes
	for child in main_panel.get_children():
		child.queue_free()

	# Rebuild sorted grid
	for card_data in all_cards:
		var card_ui_scene := preload("res://UI/CardUI.tscn")
		var card_ui: Control = card_ui_scene.instantiate()
		card_ui.card_data = card_data
		card_ui.refresh()
		main_panel.add_child(card_ui)

		card_ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(card_ui))
		card_ui.connect("request_show_zoom", Callable(self, "_on_card_hovered"))
		card_ui.connect("request_hide_zoom", Callable(self, "_on_card_unhovered"))

func _compare_cards(a: CardData, b: CardData) -> bool:
	var result := 0

	match _sort_mode:
		"name":
			result = a.name.naturalnocasecmp_to(b.name)

		"rarity":
			# Map rarity names or enum values to an order index
			var rarity_order := {
				"common": 0,
				"uncommon": 1,
				"rare": 2,
				"epic": 3,
				"legendary": 4,
				"mythic": 5
			}

			var a_val := 0
			var b_val := 0

			# Handle both string and enum cases safely
			if typeof(a.rarity) == TYPE_STRING:
				a_val = rarity_order.get(a.rarity.to_lower(), 0)
			else:
				a_val = int(a.rarity)

			if typeof(b.rarity) == TYPE_STRING:
				b_val = rarity_order.get(b.rarity.to_lower(), 0)
			else:
				b_val = int(b.rarity)

			result = a_val - b_val

		"cost":
			result = int(a.cost) - int(b.cost)

	return result < 0 if _sort_ascending else result > 0

# ==========================================================
# 🧭 TUTORIAL_STAGE SWITCHING
# ==========================================================
func _show_tutorial_stage_1():
	tutorial_popups.visible = true
	tutorial_label.clear()
	tutorial_label.bbcode_enabled = true

	tutorial_label.append_text("[center][b]Great![/b][/center]\n\n")
	tutorial_label.append_text("Now that you know how to access the [b]Card Collection[/b], let's take the next step.\n\n")
	tutorial_label.append_text("To build and modify your deck, navigate to the [b]Deck Builder[/b] panel.\n\n")
	tutorial_label.append_text("Click on the [color=cyan][b]\"D\"[/b][/color] on the toolbar to continue!")
	tutorial_label.visible_characters = 0
	tutorial_can_continue = false
	_unlock_tutorial_continue()
	
	var tween = create_tween()
	tween.tween_property(tutorial_label, "visible_characters", tutorial_label.get_total_character_count(), 1.75)

func _show_tutorial_stage_2():
	tutorial_popups.visible = true
	tutorial_label.clear()
	tutorial_label.bbcode_enabled = true

	tutorial_label.append_text("[center][b]Welcome to the Deck Builder![/b][/center]\n\n")
	tutorial_label.append_text("Here, you assemble the cards you’ll bring into battle.\n\n")
	tutorial_label.append_text("You can bring in any amount of cards, the maximum right now is 10.\n\n")
	tutorial_label.append_text("• Click a card to add it to your deck.\n")
	tutorial_label.append_text("• Click again to remove it.\n\n")
	tutorial_label.append_text("Try building your first deck now with your first 5 cards!")
	tutorial_label.visible_characters = 0
	tutorial_can_continue = false
	_unlock_tutorial_continue()
	
	var tween = create_tween()
	tween.tween_property(tutorial_label, "visible_characters", tutorial_label.get_total_character_count(), 1.75)


func _show_tutorial_stage_3():
	tutorial_popups.visible = true
	tutorial_label.clear()
	tutorial_label.bbcode_enabled = true

	tutorial_label.append_text("[center][b]Your First Deck Is Ready![/b][/center]\n\n")
	tutorial_label.append_text("Throughout your adventure, you will discover many cards from different [b]elements[/b] and [b]types[/b].\n\n")
	tutorial_label.append_text("Experiment and get creative — some cards work brilliantly together!\n\n")
	tutorial_label.append_text("Each card also has a [b]rarity[/b] that describes both how powerful and how difficult it is to find.\n\n")
	tutorial_label.append_text("When you're ready to continue, close this screen by pressing [color=yellow][b]X[/b][/color] or [color=yellow][b]TAB[/b][/color].\n\n")
	tutorial_label.append_text("[center]You can return here anytime with [b]TAB[/b].[/center]")

	tutorial_label.visible_characters = 0
	tutorial_can_continue = false
	_unlock_tutorial_continue()

	var tween = create_tween()
	tween.tween_property(tutorial_label, "visible_characters", tutorial_label.get_total_character_count(), 1.75)

func _unlock_tutorial_continue():
	continue_btn.disabled = true
	continue_btn.visible = false
	await get_tree().create_timer(5.0).timeout
	tutorial_can_continue = true
	continue_btn.visible = true
	continue_btn.disabled = false
# ==========================================================
# 🧭 PANEL SWITCHING
# ==========================================================
func _on_leader_button_pressed() -> void:
	collection_panel.visible = false
	deck_panel.visible = false
	leader_panel.visible = true
	main_panel_label.text = "Leader Selection"

func _on_deck_button_pressed() -> void:
	collection_panel.visible = false
	sort_button.visible = false
	deck_panel.visible = true
	leader_panel.visible = false
	main_panel_label.text = "Deck Builder"

	# ✅ Stage 2 tutorial (if you want continuation later)
	if Globals.tutorial_stage == 1:
		_show_tutorial_stage_2()
		Globals.tutorial_stage = 2

func _on_collection_button_pressed() -> void:
	collection_panel.visible = true
	deck_panel.visible = false
	leader_panel.visible = false
	main_panel_label.text = "Card Collection"

	# ✅ NEW tutorial page trigger
	if Globals.tutorial_stage == 0:
		_show_tutorial_stage_1()
		Globals.tutorial_stage = 1

func _on_x_pressed() -> void:
	player._toggle_collection()


func _on_tutorial_continue_button_pressed() -> void:
	if not tutorial_can_continue:
		return # too early!
	tutorial_popups.visible = false
