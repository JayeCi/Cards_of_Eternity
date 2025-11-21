extends Control

## Shop Panel
## Displays purchasable cards and card packs with lottery-style animations

signal shop_closed
signal card_purchased(card: CardData)
signal pack_purchased(cards: Array[CardData])

@onready var card_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/CardGrid
@onready var pack_button: Button = $Panel/MarginContainer/VBoxContainer/PackSection/PackButton
@onready var pack_animation: Control = $PackAnimation
@onready var pack_card_1: Control = $PackAnimation/Card1
@onready var pack_card_2: Control = $PackAnimation/Card2
@onready var pack_card_3: Control = $PackAnimation/Card3
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/TopBar/CloseButton
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TopBar/TitleLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const CARD_UI = preload("res://UI/CardUI.tscn")
const SHOP_INVENTORY_SIZE := 8  # Number of cards to display in shop
const PACK_CARD_COUNT := 3  # Number of cards in a pack
const CARD_PACK_COST := 50  # Gold cost for card pack

var _shop_inventory: Array[CardData] = []
var _is_opening_pack := false

# Rarity-based pricing (cheapest 10g, most expensive 100g)
var _rarity_prices := {
	"common": 10,
	"uncommon": 20,
	"rare": 40,
	"epic": 70,
	"legendary": 90,
	"mythic": 100
}

# -----------------------------------------------------
# Initialization
# -----------------------------------------------------
func _ready():
	visible = false
	pack_animation.visible = false

	# Connect buttons
	close_button.pressed.connect(_on_close_pressed)
	pack_button.pressed.connect(_on_pack_button_pressed)

	# Update pack button text with price
	pack_button.text = "OPEN CARD PACK (%d Gold)" % CARD_PACK_COST

	# Generate initial inventory
	_generate_shop_inventory()

# -----------------------------------------------------
# Pricing
# -----------------------------------------------------
func _get_card_price(card: CardData) -> int:
	"""Get the price of a card based on its rarity"""
	if card.rarity in _rarity_prices:
		return _rarity_prices[card.rarity]
	return _rarity_prices["common"]  # Default to common price

# -----------------------------------------------------
# Shop Opening
# -----------------------------------------------------
func open_shop():
	visible = true
	_generate_shop_inventory()
	_populate_shop_display()

	# Play slide-in animation if available
	if animation_player and animation_player.has_animation("Slide_In"):
		animation_player.play("Slide_In")

func close_shop():
	# Play slide-out animation if available
	if animation_player and animation_player.has_animation("Slide_Out"):
		animation_player.play("Slide_Out")
		await animation_player.animation_finished

	visible = false
	shop_closed.emit()

# -----------------------------------------------------
# Inventory Generation
# -----------------------------------------------------
func _generate_shop_inventory():
	_shop_inventory.clear()

	# Get all available cards from CardDB
	var all_cards := _get_all_cards_from_db()

	if all_cards.is_empty():
		push_warning("⚠️ No cards found in CardDB for shop inventory")
		return

	# Randomly select cards for shop inventory
	for i in range(SHOP_INVENTORY_SIZE):
		var random_card = all_cards.pick_random()
		if random_card:
			_shop_inventory.append(random_card)

func _get_all_cards_from_db() -> Array[CardData]:
	var cards: Array[CardData] = []

	# Get all card paths from CardDB
	var card_paths = [
		# Monster Cards - Earth
		"res://Cards/Monster Cards/Dirt.tres",
		"res://Cards/Monster Cards/Forest_Fae.tres",
		"res://Cards/Monster Cards/Stone_Fae.tres",
		"res://Cards/Monster Cards/Stone_Guard.tres",
		"res://Cards/Monster Cards/Porcu-Beast.tres",
		"res://Cards/Monster Cards/Earthrealm_Machinist.tres",
		# Monster Cards - Fire
		"res://Cards/Monster Cards/Flame_Fae.tres",
		"res://Cards/Monster Cards/Lava_Hare.tres",
		"res://Cards/Monster Cards/Jester_of_Flames.tres",
		"res://Cards/Monster Cards/Fyra.tres",
		"res://Cards/Monster Cards/Molten_Pig.tres",
		# Monster Cards - Water
		"res://Cards/Monster Cards/Lyzard.tres",
		"res://Cards/Monster Cards/Fysh.tres",
		"res://Cards/Monster Cards/Drake_of_Emerald.tres",
		"res://Cards/Monster Cards/Ice_Crab.tres",
		"res://Cards/Monster Cards/Cold_Sloth.tres",
		# Monster Cards - Wind
		"res://Cards/Monster Cards/Cloud_Monkey.tres",
		"res://Cards/Monster Cards/Falcreep.tres",
		"res://Cards/Monster Cards/Gale_Spirit.tres",
		# Monster Cards - Shadow
		"res://Cards/Monster Cards/Voidling_Ero.tres",
		"res://Cards/Monster Cards/Plague_Sentinel.tres",
		"res://Cards/Monster Cards/Bone_Warrior_Raccoon.tres",
		"res://Cards/Monster Cards/Bonehorn.tres",
		# Monster Cards - Fighters
		"res://Cards/Monster Cards/Goblin.tres",
		"res://Cards/Monster Cards/Imp.tres",
		"res://Cards/Monster Cards/Naga.tres",
		"res://Cards/Monster Cards/Axo_the_Knight.tres",
		"res://Cards/Monster Cards/Snaptrap.tres",
		"res://Cards/Monster Cards/Boogles.tres",
		"res://Cards/Monster Cards/Fungoo.tres",
		"res://Cards/Monster Cards/Finn.tres",
		"res://Cards/Monster Cards/Ninjoad.tres",
		"res://Cards/Monster Cards/Mushmonk.tres",
		"res://Cards/Monster Cards/Zei_Panda.tres",
		"res://Cards/Monster Cards/Yorg_Archer.tres",
		"res://Cards/Monster Cards/Minotaur_Warlord.tres",
		# Spell Cards
		"res://Cards/Spells/Fireball.tres",
		"res://Cards/Spells/Eruption.tres",
		"res://Cards/Spells/Conflaguration_Blade.tres",
		"res://Cards/Spells/Tidal_Wave.tres",
		"res://Cards/Spells/Aqua_Whip.tres",
		"res://Cards/Spells/Permafrost.tres",
		"res://Cards/Spells/Tsunami.tres",
		"res://Cards/Spells/Enraging_Forest.tres",
		"res://Cards/Spells/Wind_Armor.tres",
		"res://Cards/Spells/Orb_of_Darkness.tres",
		"res://Cards/Spells/Orb_of_Frost.tres",
	]

	# Load all cards that exist
	for path in card_paths:
		if ResourceLoader.exists(path):
			var card = load(path) as CardData
			if card:
				cards.append(card)

	return cards

# -----------------------------------------------------
# Shop Display
# -----------------------------------------------------
func _populate_shop_display():
	# Clear existing cards
	for child in card_grid.get_children():
		child.queue_free()

	# Add shop inventory cards
	for card_data in _shop_inventory:
		var card_ui = CARD_UI.instantiate()
		card_grid.add_child(card_ui)
		card_ui.card_data = card_data
		card_ui.refresh()

		# Make cards clickable for purchase
		var price = _get_card_price(card_data)
		card_ui.gui_input.connect(_on_card_clicked.bind(card_data, card_ui, price))

		# Add price label with actual price
		_add_price_label(card_ui, price)

func _add_price_label(card_ui: Control, price: int):
	# Create a price label overlay
	var price_label = Label.new()
	price_label.text = "💰 " + str(price) + "g"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 16)

	# Style the label
	var label_settings = LabelSettings.new()
	label_settings.font_size = 16
	label_settings.outline_size = 4
	label_settings.outline_color = Color.BLACK
	label_settings.font_color = Color.GOLD
	price_label.label_settings = label_settings

	# Position at bottom of card
	price_label.position = Vector2(0, card_ui.size.y - 30)
	price_label.size = Vector2(card_ui.size.x, 30)
	card_ui.add_child(price_label)

# -----------------------------------------------------
# Card Purchase
# -----------------------------------------------------
func _on_card_clicked(event: InputEvent, card_data: CardData, card_ui: Control, price: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_purchase_card(card_data, card_ui, price)

func _purchase_card(card_data: CardData, card_ui: Control, price: int):
	if not card_data:
		return

	# Check if player has enough gold
	if not GameSession.has_gold(price):
		print("❌ Not enough gold to purchase ", card_data.name, ". Need ", price, "g")
		# TODO: Show visual feedback (shake card, show message, etc.)
		return

	# Spend the gold
	if not GameSession.spend_gold(price):
		return

	print("🛒 Purchased: ", card_data.name, " for ", price, " gold")

	# Add to collection
	CardCollection.add_card(card_data, 1)

	# Emit signal
	card_purchased.emit(card_data)

	# Visual feedback - fade out the purchased card
	var tween = create_tween()
	tween.tween_property(card_ui, "modulate:a", 0.0, 0.3)
	tween.tween_callback(card_ui.queue_free)

	# Remove from shop inventory
	_shop_inventory.erase(card_data)

	# Optionally replace with a new card
	await get_tree().create_timer(0.3).timeout
	_replace_purchased_card(card_ui)

func _replace_purchased_card(old_card_ui: Control):
	# Generate a new random card to replace the purchased one
	var all_cards := _get_all_cards_from_db()
	if all_cards.is_empty():
		return

	var new_card = all_cards.pick_random()
	_shop_inventory.append(new_card)

	# Create new card UI
	var card_ui = CARD_UI.instantiate()
	card_grid.add_child(card_ui)
	card_ui.card_data = new_card
	card_ui.refresh()
	card_ui.modulate.a = 0.0

	# Make it clickable with price
	var price = _get_card_price(new_card)
	card_ui.gui_input.connect(_on_card_clicked.bind(new_card, card_ui, price))
	_add_price_label(card_ui, price)

	# Fade in animation
	var tween = create_tween()
	tween.tween_property(card_ui, "modulate:a", 1.0, 0.3)

# -----------------------------------------------------
# Card Pack System
# -----------------------------------------------------
func _on_pack_button_pressed():
	if _is_opening_pack:
		return

	# Check if player has enough gold
	if not GameSession.has_gold(CARD_PACK_COST):
		print("❌ Not enough gold to purchase card pack. Need ", CARD_PACK_COST, "g")
		# TODO: Show visual feedback
		return

	# Spend the gold
	if not GameSession.spend_gold(CARD_PACK_COST):
		return

	_is_opening_pack = true
	pack_button.disabled = true

	# Generate 3 random cards with weighted rarity (HIGH chance common/uncommon/rare, LOW chance epic/legendary/mythic)
	var pack_cards: Array[CardData] = []
	var all_cards := _get_all_cards_from_db()

	for i in range(PACK_CARD_COUNT):
		if not all_cards.is_empty():
			var card = _pick_weighted_random_card(all_cards)
			pack_cards.append(card)

	# Play pack opening animation
	await _play_pack_opening_animation(pack_cards)

	# Add cards to collection
	for card in pack_cards:
		CardCollection.add_card(card, 1)

	# Emit signal
	pack_purchased.emit(pack_cards)

	_is_opening_pack = false
	pack_button.disabled = false

func _pick_weighted_random_card(cards: Array[CardData]) -> CardData:
	"""Pick a random card with weighted rarity (HIGH common/uncommon/rare, LOW epic/legendary/mythic)"""
	# Weighted pool: common/uncommon/rare have much higher chance
	var rarity_weights := {
		"common": 40,      # 40% chance (HIGH)
		"uncommon": 35,    # 35% chance (HIGH)
		"rare": 20,        # 20% chance (HIGH)
		"epic": 3,         # 3% chance (LOW)
		"legendary": 1.5,  # 1.5% chance (LOW)
		"mythic": 0.5      # 0.5% chance (VERY LOW)
	}

	# Filter cards by rarity and create weighted pool
	var weighted_pool: Array[CardData] = []

	for card in cards:
		var weight = rarity_weights.get(card.rarity, 1.0)
		# Add card multiple times based on weight (convert weight to int)
		for i in range(int(weight)):
			weighted_pool.append(card)

	if weighted_pool.is_empty():
		return cards.pick_random()  # Fallback

	return weighted_pool.pick_random()

func _play_pack_opening_animation(pack_cards: Array[CardData]):
	if pack_cards.size() != 3:
		push_warning("⚠️ Pack must contain exactly 3 cards")
		return

	# Show pack animation overlay
	pack_animation.visible = true
	pack_animation.modulate.a = 0.0

	# Fade in
	var fade_tween = create_tween()
	fade_tween.tween_property(pack_animation, "modulate:a", 1.0, 0.3)
	await fade_tween.finished

	# Get card slots
	var card_slots = [pack_card_1, pack_card_2, pack_card_3]

	# Initialize card UIs
	for i in range(3):
		# Clear existing children
		for child in card_slots[i].get_children():
			child.queue_free()

		# Create card UI
		var card_ui = CARD_UI.instantiate()
		card_slots[i].add_child(card_ui)
		card_ui.card_data = pack_cards[i]
		card_ui.refresh()
		card_ui.scale = Vector2.ZERO
		card_ui.rotation = randf_range(-PI, PI)

	# Animate cards spinning and revealing one by one
	for i in range(3):
		var card_ui = card_slots[i].get_child(0)

		# Spin and scale animation
		var spin_tween = create_tween().set_parallel(true)
		spin_tween.tween_property(card_ui, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		spin_tween.tween_property(card_ui, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		# Wait for this card to finish before revealing next
		await get_tree().create_timer(0.4).timeout

	# Hold cards on screen
	await get_tree().create_timer(2.5).timeout

	# Fade out pack animation
	var fadeout_tween = create_tween()
	fadeout_tween.tween_property(pack_animation, "modulate:a", 0.0, 0.4)
	await fadeout_tween.finished

	pack_animation.visible = false

# -----------------------------------------------------
# Closing
# -----------------------------------------------------
func _on_close_pressed():
	close_shop()
