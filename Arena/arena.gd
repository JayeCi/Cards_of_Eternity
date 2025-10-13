extends Node3D

# -- Camera controls (WASD + optional zoom) ---
@export var camera_move_speed: float = 5.0
@export var camera_zoom_speed: float = 10.0
@export var min_zoom: float = 3.0
@export var max_zoom: float = 20.0
@export var enemy_deck: Array = []

signal battle_finished(result: String)

var _camera_target_height := 0.0
var _zoom_distance := 20.0
var _is_freelook := false
var _rotation_x := deg_to_rad(45)  # pitch
var _rotation_y := 0.0             # yaw
var _mouse_sensitivity := 0.005
var acted_this_turn := {} # {UnitData: true}
var _is_camera_locked: bool = false
var active_npc: Node = null

const BOARD_W := 7
const BOARD_H := 7
const PLAYER := 0
const ENEMY := 1
const CARD_MOVE_SOUND = preload("res://Audio/Sound FX/CardMove.mp3")

enum Phase { SUMMON_OR_MOVE, SELECT_SUMMON_TILE, SELECT_MOVE_TARGET, ENEMY_TURN }
var phase := Phase.SUMMON_OR_MOVE
var summon_mode := UnitData.Mode.ATTACK

@onready var board: Node3D = $Board3D
@onready var camera: Camera3D = $Camera3D
@onready var hand_grid: GridContainer = $UI/Hand
@onready var phase_label: Label = $UI/PhaseLabel
@onready var player_hp_label: Label = $UI/HPPanel/PlayerHP
@onready var enemy_hp_label: Label = $UI/HPPanel/EnemyHP
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var summon_mode_popup: Popup = $UI/SummonMode
@onready var battle_log: RichTextLabel = $UI/VBoxContainer/BattleLogLabel
@onready var card_draw: AudioStreamPlayer = $UI/SFX/CardDraw
@onready var card_details_ui: ArenaCardDetails = $UI/ArenaCardDetails


# Gameplay data
var player_deck: Array = []
var player_hand: Array = []
var enemy_hand: Array = []

var player_leader: UnitData
var enemy_leader: UnitData
var units := {}  # Dictionary<Vector2i, UnitData>

# Selection / drag state
var selected_card: CardData
var selected_pos := Vector2i(-1,-1)
var dragging_card: CardData
var hovered_tile: Node3D
var ghost_card: Sprite3D
var hover_label: Label3D

@onready var player_essence_label: Label = $UI/EssencePanel/VBoxContainer/PlayerEssence
@onready var enemy_essence_label: Label = $UI/EssencePanel/VBoxContainer/EnemyEssence

var player_essence: int = 1
var enemy_essence: int = 1
var essence_gain_per_turn: int = 1

# Card back
const CARD_BACK = preload("res://Images/CardBack1.png")

const DIRT = preload("res://Cards/Dirt.tres")
const GOBLIN = preload("res://Cards/Goblin.tres")
const IMP = preload("res://Cards/Imp.tres")
const FYSH = preload("res://Cards/Fish.tres")
const NAGA = preload("res://Cards/Naga.tres")
const COLD_SLOTH = preload("res://Cards/Cold_Sloth.tres")
const LAVA_HARE = preload("res://Cards/Lava_Hare.tres")
const FOREST_FAE = preload("res://Cards/Forest_Fae.tres")

const MAX_HAND_SIZE := 5
const MAX_ENEMY_HAND_SIZE := 5
const BASE_MOVE_RANGE := 1

# -------------------------------------------------------------------
func _ready():
	
	await get_tree().process_frame 
	set_process(true)
	# setup hover label
	hover_label = Label3D.new()
	hover_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hover_label.no_depth_test = true
	hover_label.pixel_size = 0.0025
	hover_label.set("theme_override_font_sizes/font_size", 72)
	hover_label.visible = false
	add_child(hover_label)

	# ghost card
	ghost_card = Sprite3D.new()
	ghost_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost_card.no_depth_test = true
	ghost_card.modulate = Color(1, 1, 1, 0.8)
	ghost_card.pixel_size = 0.005
	ghost_card.scale = Vector3.ONE * 0.5
	ghost_card.visible = false
	add_child(ghost_card)

	## cards & decks
	CardCollection.add_card(GOBLIN)
	CardCollection.add_card(DIRT)
	CardCollection.add_card(IMP)
	CardCollection.add_card(FYSH)
	CardCollection.add_card(NAGA)
	CardCollection.add_card(FOREST_FAE)
	CardCollection.add_card(COLD_SLOTH)
	CardCollection.add_card(LAVA_HARE)

	board.set_board_layout("forest_meadow")
	_build_decks()
	_spawn_leaders()
	await play_intro_cutscene()

	player_hp_label.text = "Player Leader HP: %d" % player_leader.hp
	enemy_hp_label.text = "Enemy Leader HP: %d" % enemy_leader.hp

	# ✅ Ensure essence labels and logic are set first
	_update_essence_labels()

	_draw_starting_hand(5)

	# ✅ Now hand can check essence properly
	_refresh_hand_ui()
	_update_phase_label()
	_position_camera()

# -------------------------------------------------------------------
# --- Deck / hand setup ---
func _build_decks():
	var all_ids = CardCollection.get_all_cards()
	if all_ids.is_empty():
		push_warning("⚠️ No cards in player collection!")

	# --- Player Deck ---
	player_deck.clear()
	for id in all_ids:
		var count = CardCollection.get_card_count(id)
		var card_data = CardCollection.get_card_data(id)
		for i in range(count):
			player_deck.append(card_data.duplicate())

	player_deck.shuffle()

	# --- Enemy Deck ---
	if enemy_deck.is_empty():
		enemy_deck.clear()
		for id in ["IMP", "GOBLIN"]:  # fallback defaults
			if ResourceLoader.exists("res://Cards/%s.tres" % id):
				var card = ResourceLoader.load("res://Cards/%s.tres" % id)
				for i in range(10):  # each enemy card repeated for test
					enemy_deck.append(card.duplicate())
		enemy_deck.shuffle()

	log_message("✅ Decks built: Player = %d, Enemy = %d" % [player_deck.size(), enemy_deck.size()])


func _draw_starting_hand(n: int) -> void:
	for i in range(n):
		var new_card = _draw_card()
		if not new_card:
			return
		await _animate_card_draw(new_card)
		await get_tree().create_timer(0.15).timeout

func _animate_card_draw(card_ui: Control) -> void:
	if not card_ui:
		return
	card_ui.modulate.a = 0.0
	card_ui.scale = Vector2(0.8, 0.8)
	card_ui.visible = true

	var t = create_tween()
	t.tween_property(card_ui, "modulate:a", 1.0, 0.25)
	t.tween_property(card_ui, "scale", Vector2(1, 1), 0.25)
	await t.finished


func _enemy_draw_up_to_hand_limit():
	print("🤖 Enemy hand:", enemy_hand.size(), " Deck:", enemy_deck.size())
	var before = enemy_hand.size()
	while enemy_hand.size() < MAX_ENEMY_HAND_SIZE and not enemy_deck.is_empty():
		_enemy_draw_card()
	print("After draw -> Enemy hand:", enemy_hand.size(), " Deck:", enemy_deck.size())

func _enemy_draw_card():
	if enemy_deck.is_empty():
		print("Enemy deck empty!")
		return
	var card = enemy_deck.pop_back()
	enemy_hand.append(card)
	print("Enemy drew", card.name)

func _draw_up_to_hand_limit() -> void:
	while player_hand.size() < MAX_HAND_SIZE and not player_deck.is_empty():
		var new_card = _draw_card()
		if not new_card:
			break
		await _animate_card_draw(new_card)
		await get_tree().create_timer(0.15).timeout

func _smooth_return_to_origin():
	var spacing = board.spacing
	var board_center = Vector3(0, 0, 1)
	var board_depth = (BOARD_H - 1) * spacing
	var board_width = (BOARD_W - 1) * spacing
	var t = create_tween()

	var target_zoom = max(board_width, board_depth) * 0.8
	var angle = deg_to_rad(45)
	var target_pos = Vector3(0, sin(angle) * target_zoom * 1.5, cos(angle) * target_zoom * 1.5)

	t.tween_property(camera, "position", target_pos, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): _look_at_target(board_center))

func _start_player_turn():
	_smooth_return_to_origin()

	print("🔁 Starting new player turn...")
	_reset_action_flags()
	show_battle_message("Your Turn!", 1.5)
	_draw_up_to_hand_limit()
	phase = Phase.SUMMON_OR_MOVE
	_update_phase_label()
	player_essence += essence_gain_per_turn
	_update_essence_labels()
	_apply_all_passives()

	# hand fade-in you added
	hand_grid.visible = true
	hand_grid.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(hand_grid, "modulate:a", 1.0, 0.25)

func _draw_card() -> Control:
	if player_deck.is_empty():
		return null
	var card = player_deck.pop_back()
	player_hand.append(card)
	_refresh_hand_ui()  # refresh to add the new card
	card_draw.play()
	var new_card_ui = hand_grid.get_child(hand_grid.get_child_count() - 1)
	return new_card_ui

func _refresh_hand_ui():
	for child in hand_grid.get_children():
		child.queue_free()

	for c in player_hand:
		var ui = preload("res://UI/CardUI.tscn").instantiate()
		ui.card_data = c
		ui.refresh()

		# 🔹 Determine if this card is playable with current essence
		var cost := 1
		if c.has_meta("cost"):
			cost = int(c.get_meta("cost"))
		elif c.has_method("get_cost"):
			cost = c.get_cost()
		elif "cost" in c:
			cost = int(c.cost)

		ui.set_playable(cost <= player_essence)

		ui.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if cost > player_essence:
					# optional feedback: pulse red briefly
					var t = create_tween()
					t.tween_property(ui, "modulate", Color(1, 0.5, 0.5, 1), 0.1)
					t.tween_property(ui, "modulate", Color(0.4, 0.4, 0.4, 0.5), 0.25)
					log_message("❌ Not enough Essence for %s (Cost %d, you have %d)" % [c.name, cost, player_essence])
					return
				_on_hand_card_clicked(c))

		hand_grid.add_child(ui)

# -------------------------------------------------------------------
# --- Dragging and hovering ---
func _process(_dt):
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_hover_highlight()
	_update_ghost_position()
func _physics_process(delta: float) -> void:
	_handle_camera_movement(delta)
	
func _update_ghost_position():
	if not dragging_card or not ghost_card.visible:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var default_pos = from + dir * 5.0

	if hovered_tile:
		ghost_card.position = hovered_tile.position + Vector3(0, 0.03, 0)
	else:
		ghost_card.position = default_pos

# -------------------------------------------------------------------
func _handle_camera_movement(delta: float) -> void:
	if not camera:
		return

	var move_input := Vector3.ZERO
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	# --- WASD Input ---
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"):
		move_input -= right
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"):
		move_input += right
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_forward"):
		move_input += forward
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_downward"):
		move_input -= forward

	if move_input != Vector3.ZERO:
		camera.position += move_input.normalized() * camera_move_speed * delta


	# --- Zoom ---
	var zoom_changed := false
	if Input.is_action_pressed("wheel_up"):
		_zoom_distance -= camera_zoom_speed * delta * 5
		zoom_changed = true
	if Input.is_action_pressed("wheel_down"):
		_zoom_distance += camera_zoom_speed * delta * 5
		zoom_changed = true

	_zoom_distance = clamp(_zoom_distance, min_zoom, max_zoom)

	if zoom_changed:
		var angle := deg_to_rad(45)
		camera.position.y = sin(angle) * _zoom_distance * 1.5
		camera.position.z = cos(angle) * _zoom_distance * 1.5

	camera.position.y = clamp(camera.position.y, 3.0, 25.0)
	_clamp_camera_to_board()

func _update_hover_highlight():
	var result = _ray_pick(get_viewport().get_mouse_position())
	var tile: Node3D = null

	if result:
		var node = result.collider
		# If we hit the collision body inside the Tile3D, climb up to its parent
		if node is CollisionShape3D or node is StaticBody3D:
			node = node.get_parent()
		# Verify the parent is indeed a tile
		if node and node.has_method("set_highlight"):
			tile = node



	if tile and tile != hovered_tile:
		print("Hovering tile:", tile.x, tile.y)

	# Unhighlight the previous tile if we moved off
	if hovered_tile and hovered_tile != tile:
		hovered_tile.set_highlight(false)
		hovered_tile = null
		_hide_hover_label()


	if tile:
		var valid: bool = true
		var symbol := "★" if dragging_card else ""
		tile.set_highlight(valid, symbol)
		hovered_tile = tile

		# If dragging a card, move ghost card above it
		if dragging_card and ghost_card.visible:
			ghost_card.position = tile.position + Vector3(0, 0.03, 0)

		# 🔹 NEW: Show stats above hovered tile
		_show_hover_label(tile)
		#🔹 Show full card details if the tile has a unit
		if tile.occupant:
			card_details_ui.show_unit(tile.occupant)
		else:
			card_details_ui.hide_card()


	else:
		_hide_hover_label()


func _show_hover_label(tile: Node3D):
	if not tile:
		_hide_hover_label()
		return

	var text := ""

	# --- If the tile has an occupant (unit or leader)
	if tile.occupant:
		var u: UnitData = tile.occupant
		if u.is_leader:
			text += "👑 Leader (" + u.card.name + ")\n"
		else:
			text += u.card.name + "\n"

		text += "🗡 " + str(u.current_atk) + " | 🛡 " + str(u.current_def)
		if u.is_leader:
			text += " | ❤️ " + str(u.hp)
		text += "\n"

	# --- Always show terrain type
	text += "🌍 Terrain: " + tile.terrain_type

	var pos = tile.global_position + Vector3(0, 0.25, 0)
	hover_label.global_position = pos
	hover_label.text = text
	hover_label.visible = true

	var t = create_tween()
	hover_label.modulate.a = 0.0
	t.tween_property(hover_label, "modulate:a", 1.0, 0.2)

func _hide_hover_label():
	if not hover_label.visible:
		return
	var t = create_tween()
	t.tween_property(hover_label, "modulate:a", 0.0, 0.15)
	await t.finished
	card_details_ui.hide_card()
	hover_label.visible = false

func _ray_pick(screen_pos: Vector2) -> Dictionary:
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	var to = from + dir * 100
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q)

# -------------------------------------------------------------------
func _unhandled_input(event):
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			if event.pressed:
				_enter_freelook_mode()
			else:
				_exit_freelook_mode()

	if _is_freelook and event is InputEventMouseMotion:
		_handle_freelook_mouse(event.relative)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if dragging_card: _try_place_dragged_card()
			else: _handle_board_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click_anywhere()
			
func _enter_freelook_mode():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_is_freelook = true
	print("🎥 Freelook mode enabled")

func _exit_freelook_mode():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_is_freelook = false
	print("🎥 Freelook mode disabled")

	# Smoothly reorient camera back to default top-down view
	var target_angle := deg_to_rad(45)
	var t = create_tween()
	t.tween_property(self, "_rotation_x", target_angle, 0.3)
	t.tween_property(self, "_rotation_y", 0.0, 0.3)
	t.tween_callback(Callable(self, "_reset_camera_orientation"))

func _reset_camera_orientation():
	var spacing = board.spacing
	var board_center = Vector3(0, 0, 1)
	var board_depth = (BOARD_H - 1) * spacing
	var board_width = (BOARD_W - 1) * spacing

	_zoom_distance = max(board_width, board_depth) * 0.8
	var angle = deg_to_rad(45)
	camera.position = Vector3(0, sin(angle) * _zoom_distance * 1.5, cos(angle) * _zoom_distance * 1.5)
	camera.look_at(board_center, Vector3.UP)

func _handle_freelook_mouse(relative: Vector2):
	_rotation_y -= relative.x * _mouse_sensitivity
	_rotation_x += relative.y * _mouse_sensitivity  # ✅ flip Y direction
	_rotation_x = clamp(_rotation_x, deg_to_rad(10), deg_to_rad(80))

	var offset = Vector3()
	offset.x = sin(_rotation_y) * _zoom_distance
	offset.z = cos(_rotation_y) * _zoom_distance
	offset.y = tan(_rotation_x) * _zoom_distance * 0.75

	camera.position = offset
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)

# -------------------------------------------------------------------
# --- Card drag start / stop ---
func _on_hand_card_clicked(c: CardData):
	selected_card = c
	dragging_card = c
	ghost_card.texture = c.art
	ghost_card.visible = true
	hand_grid.visible = false
	phase = Phase.SELECT_SUMMON_TILE
	_update_phase_label()
	_show_valid_summon_tiles()

	# Immediately put ghost in front of camera
	var forward = -camera.global_transform.basis.z
	ghost_card.position = camera.global_position + forward * 5.0

func _show_valid_summon_tiles():
	_clear_highlights()
	var leader_pos := _get_leader_pos(PLAYER)

	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var p = leader_pos + d
		if p.x < 0 or p.y < 0 or p.x >= BOARD_W or p.y >= BOARD_H:
			continue
		var t = board.get_tile(p.x, p.y)
		if t.occupant == null:
			t.set_highlight(true, "★")

func _try_place_dragged_card():
	if not hovered_tile or hovered_tile.occupant != null:
		_cancel_drag()
		return

	var leader_pos := _get_leader_pos(PLAYER)
	var tile_pos := Vector2i(hovered_tile.x, hovered_tile.y)

	# 🔹 Check essence cost
	var cost = selected_card.cost if selected_card.has_method("cost") else 1
	if player_essence < cost:
		log_message("❌ Not enough Essence to summon %s (cost %d, you have %d)" % [
			selected_card.name, cost, player_essence
		], Color(1, 0.5, 0.3))
		_cancel_drag()
		return

	if tile_pos.distance_to(leader_pos) > 1:
		log_message("⚠️ You can only summon next to your Leader!", Color(1, 0.5, 0.2))
		_cancel_drag()
		return

	selected_pos = tile_pos
	$UI/SummonMode.popup_centered()
	ghost_card.visible = false
	dragging_card = null
	hand_grid.visible = true

func _cancel_drag():
	dragging_card = null
	ghost_card.visible = false
	hand_grid.visible = true
	_clear_highlights()
	phase = Phase.SUMMON_OR_MOVE
	_update_phase_label()

func _on_right_click_anywhere():
	if dragging_card: _cancel_drag()
	else:
		selected_card = null
		selected_pos = Vector2i(-1,-1)
		_clear_highlights()
		phase = Phase.SUMMON_OR_MOVE
		_update_phase_label()

# -------------------------------------------------------------------
# --- Board interactions ---
func _handle_board_click(screen_pos: Vector2):
	var result = _ray_pick(screen_pos)
	if not result:
		print("No hit!")
		return

	var node = result.collider

		# Climb up the node tree until we find the Tile3D (the one that has x and y)
	while node and (not node.has_meta("tile_marker")):
		node = node.get_parent()

	if not node:
		print("No tile found from collider chain.")
		return

	var tile = node
	print("Clicked tile:", tile.name, "(", tile.x, ",", tile.y, ")")

	match phase:
		Phase.SUMMON_OR_MOVE:
			if tile.occupant and tile.occupant.owner == PLAYER:
				if _has_unit_acted(tile.occupant):
					log_message("⏳ That unit already acted this turn.")
					return
				selected_pos = Vector2i(tile.x, tile.y)
				_show_move_targets(selected_pos)
				phase = Phase.SELECT_MOVE_TARGET
				_update_phase_label()

		Phase.SELECT_MOVE_TARGET:
			if tile.highlighted:
				_move_or_battle(selected_pos, Vector2i(tile.x, tile.y))
				_clear_highlights()
				selected_pos = Vector2i(-1,-1)
				phase = Phase.SUMMON_OR_MOVE
				_update_phase_label()

func _clear_highlights():
	for y in range(BOARD_H):
		for x in range(BOARD_W):
			var t = board.get_tile(x, y)
			if t: t.set_highlight(false)

# -------------------------------------------------------------------
# --- Summoning ---
func _on_attack_mode_pressed():
	summon_mode = UnitData.Mode.ATTACK
	$UI/SummonMode.hide()
	_place_selected_card()

func _on_defense_mode_pressed():
	summon_mode = UnitData.Mode.DEFENSE
	$UI/SummonMode.hide()
	_place_selected_card()

func _on_facedown_mode_pressed():
	summon_mode = UnitData.Mode.FACEDOWN
	$UI/SummonMode.hide()
	_place_selected_card()

func _place_selected_card():
	if selected_card == null or selected_pos == Vector2i(-1,-1):
		return

	var cost = selected_card.cost


	# ✅ Ensure you can still afford it
	if player_essence < cost:
		log_message("❌ Not enough Essence to summon %s (cost %d, you have %d)" % [
			selected_card.name, cost, player_essence
		], Color(1, 0.5, 0.3))
		_cancel_drag()
		return

	var prev = player_essence
	player_essence -= cost
	_update_essence_labels(prev)


	_place_unit(selected_card, selected_pos, PLAYER)
	player_hand.erase(selected_card)
	selected_card = null
	selected_pos = Vector2i(-1,-1)
	_refresh_hand_ui()
	_clear_highlights()
	phase = Phase.SUMMON_OR_MOVE
	_update_phase_label()

func _place_unit(card: CardData, pos: Vector2i, owner: int):
	
	var u := UnitData.new().init_from_card(card, owner)
	u.mode = summon_mode
	units[pos] = u
	var tile = board.get_tile(pos.x, pos.y)
	tile.occupant = u

	match u.mode:
		UnitData.Mode.ATTACK:
			tile.set_art(card.art)
			if card.ability and card.ability.trigger == "on_summon":
				_execute_card_ability(u, card.ability)

			print("🔍 Placing", card.name, "at", pos, "art:", card.art)
			print("Tile node:", tile, "Has CardMesh:", tile.has_node("CardMesh"))

		UnitData.Mode.DEFENSE:
			tile.set_art(card.art)
			print("🔍 Placing", card.name, "at", pos, "art:", card.art)
			print("Tile node:", tile, "Has CardMesh:", tile.has_node("CardMesh"))
			tile.get_node("CardMesh").rotation_degrees.y = 90
		UnitData.Mode.FACEDOWN:
			tile.set_art(CARD_BACK)
			print("🔍 Placing", card.name, "at", pos, "art:", card.art)
			print("Tile node:", tile, "Has CardMesh:", tile.has_node("CardMesh"))
			tile.get_node("CardMesh").rotation_degrees.y = 0

	tile.set_badge_text("P" if owner == PLAYER else "E")
	_mark_unit_acted(u)
	
	_play_card_sound(CARD_MOVE_SOUND, tile.global_position)
	_play_card_sound(card.place_sound, tile.global_position)
	
	if card.ability and card.ability.trigger == "on_passive":
		_apply_passive_effect(u, card.ability)
# -------------------------------------------------------------------

func _apply_passive_effect(unit: UnitData, ability: CardAbility) -> void:
	print("🌀 Applying passive ability for:", unit.card.name)
	ability.execute(self, unit)

	# Optionally mark it as active so you can remove later
	unit.set_meta("passive_active", true)


# --- Movement / battle ---
func _show_move_targets(from: Vector2i):
	_clear_highlights()
	var src = board.get_tile(from.x, from.y)
	if not src or not src.occupant: return
	if _has_unit_acted(src.occupant): return  # 🔒 already acted

	var range := BASE_MOVE_RANGE
	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			# Skip origin and diagonals beyond range
			var dist = abs(dx) + abs(dy)
			if dist == 0 or dist > range:
				continue
			var p = from + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= BOARD_W or p.y >= BOARD_H:
				continue
			var t = board.get_tile(p.x, p.y)
			if t and (t.occupant == null or t.occupant.owner != PLAYER):
				t.set_highlight(true, "•" if t.occupant == null else "⚔")

func _move_or_battle(from: Vector2i, to: Vector2i):
	var src = board.get_tile(from.x, from.y)
	var dst = board.get_tile(to.x, to.y)
	if not src or not dst: return

	var attacker: UnitData = src.occupant
	if not attacker: return
	if _has_unit_acted(attacker):
		log_message("⏳ That unit already acted this turn.")
		return

	# 🔒 --- NEW: Prevent moving more than 1 tile ---
	var dist = abs(to.x - from.x) + abs(to.y - from.y)
	if dist > BASE_MOVE_RANGE:
		log_message("⚠️ You can only move 1 tile per turn!", Color(1, 0.6, 0.4))
		return


	# same-tile and range checks you already have...

	if dst.occupant == null:
		# --- MOVE ---
		dst.occupant = attacker
		_play_card_sound(CARD_MOVE_SOUND, dst.global_position)

		# Preserve facedown visuals
		if attacker.mode == UnitData.Mode.FACEDOWN:
			dst.set_art(CARD_BACK)
		else:
			dst.set_art(attacker.card.art)

		dst.set_badge_text("P" if attacker.owner == PLAYER else "E")
		src.clear()
		units.erase(from)
		units[to] = attacker
		_mark_unit_acted(attacker)
	else:
		# 🚫 same owner check...
		var defender: UnitData = dst.occupant
		# Reveal any facedown cards before combat
		if attacker.mode == UnitData.Mode.FACEDOWN:
			attacker.mode = UnitData.Mode.ATTACK
			var attacker_tile = board.get_tile(from.x, from.y)
			await _flip_faceup(attacker_tile, attacker.card.art)
			log_message("🔄 %s was revealed in attack mode!" % attacker.card.name, Color(1, 1, 0.6))

		if defender.mode == UnitData.Mode.FACEDOWN:
			defender.mode = UnitData.Mode.DEFENSE
			var defender_tile = board.get_tile(to.x, to.y)
			await _flip_faceup(defender_tile, defender.card.art)
			log_message("❗ %s was revealed!" % defender.card.name, Color(1, 0.9, 0.7))

		var result := await _play_3d_battle(attacker, defender)
		
		match result:
			"attacker_wins":
				_kill_unit(defender)
				dst.occupant = attacker
				dst.set_art(attacker.card.art if attacker.mode != UnitData.Mode.FACEDOWN else CARD_BACK)
				dst.set_badge_text("P" if attacker.owner == PLAYER else "E")
				src.clear()
				units.erase(from)
				units[to] = attacker
				_mark_unit_acted(attacker)

			"defender_wins":
				_kill_unit(attacker)
				# defender stays; no move

			"both_destroyed":
				_kill_unit(defender)
				_kill_unit(attacker)

			"both_survive", "leader_damaged":
				dst.flash()
				_mark_unit_acted(attacker)

		# --- Final safety: if anyone hit 0 during animations, clean them up ---
		if dst.occupant and dst.occupant.current_def <= 0:
			_kill_unit(dst.occupant)
		if attacker and attacker.current_def <= 0:
			_kill_unit(attacker)

func _kill_unit(u: UnitData) -> void:
	if u == null: return
	# remove passive auras first
	if u.card and u.card.ability and u.card.ability.trigger == "on_passive":
		_remove_passive_effect(u, u.card.ability)

	var tile := _get_unit_tile(u)
	if tile:
		_play_card_sound(u.card.death_sound, tile.global_position)
		tile.clear()

	# erase from board dictionary
	for pos in units.keys():
		if units[pos] == u:
			units.erase(pos)
			break

	card_details_ui.hide_card()

func _apply_all_passives():
	for pos in units.keys():
		var u: UnitData = units[pos]
		if u.card.ability and u.card.ability.trigger == "on_passive":
			u.card.ability.execute(self, u)

func _remove_passive_effect(unit: UnitData, ability: CardAbility) -> void:
	print("💨 Removing passive effect for:", unit.card.name)
	if ability.has_method("remove"):
		ability.remove(self, unit)

func _flip_faceup(tile: Node3D, new_texture: Texture2D):
	var mesh = tile.get_node("CardMesh")
	var tw = create_tween()
	tw.tween_property(mesh, "rotation_degrees:y", 90, 0.15)
	await tw.finished
	tile.set_art(new_texture)
	tw = create_tween()
	tw.tween_property(mesh, "rotation_degrees:y", 0, 0.15)
	await tw.finished

func _resolve_battle(att: UnitData, defn: UnitData) -> String:
	var a = att.current_atk
	var d = defn.current_def
	var def_before = d

	log_message("⚔ Battle! %s (ATK %d) vs %s (ATK %d / DEF %d, Mode=%s)" % [
		att.card.name, a, defn.card.name, defn.current_atk, defn.current_def, str(defn.mode)
	], Color(1, 0.9, 0.6))

	var att_tile = _get_unit_tile(att)
	if att_tile:
		_play_card_sound(att.card.attack_sound, att_tile.global_position)

	# --- Leader logic ---
	if defn.is_leader:
		defn.hp = max(defn.hp - a, 0)
		log_message("💥 %s attacks the Leader directly for %d damage!" % [att.card.name, a], Color(1, 0.6, 0.6))
		_update_hp_labels(defn.owner)
		if defn.hp <= 0:
			_on_leader_defeated(defn.owner)
		return "leader_damaged"

	# --- Trigger attack abilities ---
	if att.card.ability and att.card.ability.trigger == "on_attack":
		_execute_card_ability(att, att.card.ability)

	# ==========================================================
	# CASE 1: Defender is in DEFENSE MODE
	# ==========================================================
	if defn.mode == UnitData.Mode.DEFENSE:
		defn.current_def = max(defn.current_def - a, 0)
		card_details_ui.refresh_if_showing(defn)

		if a > d:
			log_message("💥 %s breaks through %s’s DEF!" % [att.card.name, defn.card.name], Color(0.7, 1, 0.7))
			_play_card_sound(defn.card.death_sound)
			return "attacker_wins"
		else:
			log_message("🛡 %s’s DEF reduced from %d → %d" % [defn.card.name, def_before, defn.current_def], Color(0.8, 0.8, 1))
			_play_card_sound(defn.card.defense_sound)

			# Counterattack if defender can fight back
			if defn.current_atk > 0:
				att.current_def = max(att.current_def - defn.current_atk, 0)
				card_details_ui.refresh_if_showing(att)
				log_message("↩ %s counterattacks for %d! %s DEF → %d" % [
					defn.card.name, defn.current_atk, att.card.name, att.current_def
				], Color(1, 0.9, 0.7))
				if att.current_def <= 0:
					_play_card_sound(att.card.death_sound)
					return "defender_wins"
			return "both_survive"

	# ==========================================================
	# CASE 2: Both are in ATTACK MODE — mutual combat
	# ==========================================================
	if defn.mode == UnitData.Mode.ATTACK and att.mode == UnitData.Mode.ATTACK:
		log_message("🔥 Both monsters attack head-on!", Color(1, 0.8, 0.5))

		defn.current_def = max(defn.current_def - a, 0)
		att.current_def = max(att.current_def - defn.current_atk, 0)

		card_details_ui.refresh_if_showing(defn)
		card_details_ui.refresh_if_showing(att)

		log_message("%s DEF → %d | %s DEF → %d" % [
			defn.card.name, defn.current_def, att.card.name, att.current_def
		], Color(1, 1, 1))

		var attacker_destroyed = att.current_def <= 0
		var defender_destroyed = defn.current_def <= 0

		if attacker_destroyed and defender_destroyed:
			log_message("💀 Both are destroyed in battle!", Color(1, 0.4, 0.4))
			_play_card_sound(att.card.death_sound)
			_play_card_sound(defn.card.death_sound)
			return "both_destroyed"
		elif defender_destroyed:
			log_message("💥 %s destroys %s!" % [att.card.name, defn.card.name], Color(0.7, 1, 0.7))
			_play_card_sound(defn.card.death_sound)
			return "attacker_wins"
		elif attacker_destroyed:
			log_message("💀 %s is destroyed!" % att.card.name, Color(1, 0.4, 0.4))
			_play_card_sound(att.card.death_sound)
			return "defender_wins"
		else:
			return "both_survive"

	# ==========================================================
	# Fallback
	# ==========================================================
	return "both_survive"

func _update_hp_labels(owner: int) -> void:
	if owner == PLAYER:
		player_hp_label.text = "Player Leader HP: %d" % player_leader.hp
		_flash_hp_label(player_hp_label)
	elif owner == ENEMY:
		enemy_hp_label.text = "Enemy Leader HP: %d" % enemy_leader.hp
		_flash_hp_label(enemy_hp_label)

func _flash_hp_label(label: Label) -> void:
	var t = create_tween()
	t.tween_property(label, "modulate", Color(1, 0.5, 0.5), 0.1)
	t.tween_property(label, "modulate", Color(1, 1, 1), 0.3)

func _on_leader_defeated(owner: int) -> void:
	if owner == PLAYER:
		log_message("💀 Your Leader has fallen!", Color(1, 0.3, 0.3))
		show_battle_message("Your Leader has fallen! You lose!", 3.0)
		get_tree().paused = false  # ensure unpaused
		emit_signal("battle_finished", "player_lost")

	elif owner == ENEMY:
		log_message("🏆 Enemy Leader defeated! You win!", Color(0.3, 1, 0.3))
		show_battle_message("Enemy Leader defeated! You win!", 3.0)
		get_tree().paused = false
		emit_signal("battle_finished", "player_won")


func show_battle_message(text: String, duration: float = 2.0) -> void:
	var label = $UI/BattlePopup
	label.text = text
	label.show()

	var t = create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(duration).timeout
	var t2 = create_tween()
	t2.tween_property(label, "modulate:a", 0.0, 0.5)

# -------------------------------------------------------------------
# --- Cinematic battle ---
func _play_3d_battle(att: UnitData, defn: UnitData) -> String:
	var result: String = _resolve_battle(att, defn)

	await _fade(1.0, 0.25)  # fade out to black

	# load temporary battle scene
	var battle_scene = preload("res://Arena/battle_scene_3d.tscn").instantiate()
	add_child(battle_scene)

	battle_scene.play_battle(att.card, defn.card, result)
	await battle_scene.finished
	battle_scene.queue_free()

	await _fade(0.0, 0.25)  # fade back in

	return result


func _fade(to_alpha: float, dur: float):
	var tw = create_tween()
	tw.tween_property(fade_rect, "modulate:a", to_alpha, dur)
	await tw.finished

# -------------------------------------------------------------------
# --- Leader spawning / HP ---
func _spawn_leaders():
	player_leader = UnitData.new().init_from_card(IMP, PLAYER)
	player_leader.is_leader = true
	player_leader.hp = 10

	enemy_leader = UnitData.new().init_from_card(NAGA, ENEMY)
	enemy_leader.is_leader = true
	enemy_leader.hp = 10

	# 🔁 Swap their placement
	_place_leader(player_leader, Vector2i(BOARD_W / 2, 0))
	_place_leader(enemy_leader, Vector2i(BOARD_W / 2, BOARD_H - 1))
	# 🔹 Hide both leaders’ meshes initially
	var player_tile = board.get_tile(BOARD_W / 2, 0)
	var enemy_tile = board.get_tile(BOARD_W / 2, BOARD_H - 1)

	for t in [player_tile, enemy_tile]:
		if t and t.has_node("CardMesh"):
			var mesh = t.get_node("CardMesh")
			var mat = mesh.get_surface_override_material(0)
			if mat == null:
				mat = StandardMaterial3D.new()
				mesh.set_surface_override_material(0, mat)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var color = mat.albedo_color
			color.a = 0.0   # invisible
			mat.albedo_color = color
func _place_leader(unit: UnitData, pos: Vector2i):
	units[pos] = unit
	var tile = board.get_tile(pos.x, pos.y)
	tile.occupant = unit
	tile.set_art(unit.card.art)
	tile.set_badge_text("L")

func _update_phase_label():
	match phase:
		Phase.SUMMON_OR_MOVE:
			phase_label.text = "Your Turn: Summon or Move"
			$UI/EndTurnButton.disabled = false
		Phase.SELECT_SUMMON_TILE:
			phase_label.text = "Choose a tile to Summon"
			$UI/EndTurnButton.disabled = true
		Phase.SELECT_MOVE_TARGET:
			phase_label.text = "Choose a tile to Move"
			$UI/EndTurnButton.disabled = true
		Phase.ENEMY_TURN:
			phase_label.text = "Enemy Turn"
			$UI/EndTurnButton.disabled = true


func _position_camera():
	var spacing = board.spacing
	var board_center = Vector3(0, 0, 1)
	var board_depth = (BOARD_H - 1) * spacing
	var board_width = (BOARD_W - 1) * spacing

	_zoom_distance = max(board_width, board_depth) * 0.8
	var angle = deg_to_rad(45)
	camera.position = Vector3(0, sin(angle) * _zoom_distance * 1.5, cos(angle) * _zoom_distance * 1.5)
	camera.look_at(board_center, Vector3.UP)

# -------------------------------------------------------------------
# --- Camera boundary locking ---
func _clamp_camera_to_board():
	if _is_camera_locked:
		return  # 🔒 skip while tweening
	if not board or not camera:
		return


	var spacing = board.spacing if board.has_method("spacing") else 1.0
	var half_w = (BOARD_W - 1) * spacing * 0.5
	var half_h = (BOARD_H - 1) * spacing * 0.5
	var margin = spacing * 3.5
	var forward_extra = spacing * 3.0  # extra space toward enemy side

	var min_x = -half_w - margin
	var max_x = half_w + margin
	var min_z = -half_h - margin
	var max_z = half_h + margin + forward_extra

	# --- Compute the camera's look-at (focus) point ---
	var forward = -camera.global_transform.basis.z.normalized()
	var focus_distance := _zoom_distance * 0.6  # approximate how far camera looks ahead
	var focus_point = camera.position + forward * focus_distance

	# --- Clamp the focus point within bounds ---
	focus_point.x = clamp(focus_point.x, min_x, max_x)
	focus_point.z = clamp(focus_point.z, min_z, max_z)

	# --- Move camera so that it still looks at the clamped focus point ---
	var offset = camera.position - (camera.position + forward * focus_distance)
	var corrected_camera_pos = focus_point - forward * focus_distance
	camera.position = corrected_camera_pos

func _on_end_turn_button_pressed() -> void:
	if phase != Phase.SUMMON_OR_MOVE:
		return
	log_message("📜 Player ends their turn.")
	phase = Phase.ENEMY_TURN
	_update_phase_label()

	# Hide hand (fade out)
	hand_grid.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(hand_grid, "modulate:a", 1.0, 0.25)

	# 🔹 Enemy starts with clean action flags


	await _enemy_turn()
	log_message("🔁 Enemy turn finished.")
	_start_player_turn()
	_reset_action_flags()
func _enemy_turn() -> void:
	#var enemy_leader_pos3d = board.get_tile(_get_leader_pos(ENEMY).x, _get_leader_pos(ENEMY).y).global_position
	#_focus_camera_on(enemy_leader_pos3d, 0.8, 1.0)

	print("🤖 Enemy is thinking...")
	await get_tree().create_timer(1.0).timeout

	_enemy_draw_up_to_hand_limit() 
	_apply_all_passives()
	
	# --- Decision Making ---
	var has_units = false
	for pos in units.keys():
		if units[pos].owner == ENEMY and not units[pos].is_leader:
			has_units = true
			break

	var action: int
	if not has_units and not enemy_deck.is_empty():
		action = 0  # Summon if no units on board
	else:
		# 60% chance to attack/move, 40% to summon if space available
		action = (randi() % 100 < 40) if _enemy_has_summon_space() else 1

	if action == 0:
		await _enemy_try_summon()
		enemy_essence += essence_gain_per_turn
		_update_essence_labels()
	else:
		await _enemy_try_move_or_attack()
		


	await get_tree().create_timer(0.8).timeout
	print("Enemy ends its turn.")


func _enemy_has_summon_space() -> bool:
	var leader_pos := _get_leader_pos(ENEMY)
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var p = leader_pos + d
		if p.x >= 0 and p.y >= 0 and p.x < BOARD_W and p.y < BOARD_H:
			var t = board.get_tile(p.x, p.y)
			if t and t.occupant == null:
				return true
	return false


func _enemy_try_summon() -> void:
	if enemy_essence <= 0:
		print("Enemy has no essence to summon.")
		return

	# Only stop if the enemy has NO cards in hand AND no deck left
	if enemy_hand.is_empty() and enemy_deck.is_empty():
		print("Enemy has no cards left to summon or draw.")
		return

	var leader_pos := _get_leader_pos(ENEMY)
	var valid_tiles: Array = []

	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var p = leader_pos + d
		if p.x < 0 or p.y < 0 or p.x >= BOARD_W or p.y >= BOARD_H:
			continue
		var t = board.get_tile(p.x, p.y)
		if t and t.occupant == null:
			valid_tiles.append(p)

	if valid_tiles.is_empty():
		print("No open tiles for enemy to summon.")
		return

	# Prefer tiles closer to the player’s leader
	var player_leader_pos := _get_leader_pos(PLAYER)
	valid_tiles.sort_custom(func(a, b):
		return a.distance_to(player_leader_pos) < b.distance_to(player_leader_pos)
	)

	if enemy_hand.is_empty():
		_enemy_draw_card()
	if enemy_hand.is_empty():
		print("Enemy has no cards to summon.")
		return

	var summon_card: CardData = enemy_hand.pop_back()
	
	var cost = summon_card.cost if summon_card.has_method("cost") else 1
	if enemy_essence < cost:
		print("Enemy cannot afford", summon_card.name, "cost", cost)
		return
	var prev = enemy_essence
	enemy_essence -= cost
	_update_essence_labels(-1, prev)


	var pos = valid_tiles.front()  # closest tile to player
		# --- Focus camera on summon location ---
	var summon_tile = board.get_tile(pos.x, pos.y)
	_focus_camera_on(summon_tile.global_position, 0.8, 0.6)
	await get_tree().create_timer(0.4).timeout  # small pause for effect

	_place_unit(summon_card, pos, ENEMY)
	log_message("🤖 Enemy summoned %s at %s" % [summon_card.name, str(pos)], Color(0.8, 0.8, 1))



func _enemy_try_move_or_attack() -> void:
	var player_pos := _get_leader_pos(PLAYER)
	var movable_units: Array = []

	# Collect enemy units (excluding leader)
	for pos in units.keys():
		var u: UnitData = units[pos]
		if u.owner == ENEMY and not u.is_leader:
			movable_units.append(pos)

	if movable_units.is_empty():
		print("Enemy has no units to move.")
		return

	# --- Prioritize units close to player’s leader ---
	movable_units.sort_custom(func(a, b):
		return a.distance_to(player_pos) < b.distance_to(player_pos)
	)

	for move_pos in movable_units:
		var src = board.get_tile(move_pos.x, move_pos.y)
		if not src or not src.occupant: continue
		if _has_unit_acted(src.occupant): continue
		# ... pick target; once it moves/attacks, _mark_unit_acted() is called

		# Check for adjacent player targets
		# Check for attackable player targets within range
		var range := BASE_MOVE_RANGE
		for dx in range(-range, range + 1):
			for dy in range(-range, range + 1):
				var dist = abs(dx) + abs(dy)
				if dist == 0 or dist > range:
					continue
				var target = move_pos + Vector2i(dx, dy)
				if target.x < 0 or target.y < 0 or target.x >= BOARD_W or target.y >= BOARD_H:
					continue
				var tile = board.get_tile(target.x, target.y)
				if tile and tile.occupant and tile.occupant.owner == PLAYER:
					var attack_tile = board.get_tile(target.x, target.y)
					_focus_camera_on(attack_tile.global_position, 0.6, 0.5)
					await get_tree().create_timer(0.3).timeout
					log_message("⚔ Enemy attacks player’s unit at %s!" % str(target), Color(1, 0.7, 0.7))
					await _move_or_battle(move_pos, target)
					await get_tree().create_timer(0.4).timeout
					return


			# Otherwise, move closer to player leader
		var best_move = move_pos
		var best_dist = move_pos.distance_to(player_pos)

		for dx in range(-range, range + 1):
			for dy in range(-range, range + 1):
				var dist = abs(dx) + abs(dy)
				if dist == 0 or dist > range:
					continue
				var target = move_pos + Vector2i(dx, dy)
				if target.x < 0 or target.y < 0 or target.x >= BOARD_W or target.y >= BOARD_H:
					continue
				var t = board.get_tile(target.x, target.y)
				if t and t.occupant == null:
					var dist_to_leader = target.distance_to(player_pos)
					if dist_to_leader < best_dist:
						best_move = target
						best_dist = dist_to_leader

			if best_move != move_pos:
				var move_tile = board.get_tile(best_move.x, best_move.y)
				if move_tile:
					# 🎥 Focus camera on the tile being moved to
					_focus_camera_on(move_tile.global_position, 0.75, 0.6)
					await get_tree().create_timer(0.25).timeout  # short cinematic pause

				print("Enemy moves from %s to %s" % [str(move_pos), str(best_move)])
				await _move_or_battle(move_pos, best_move)
				await get_tree().create_timer(0.4).timeout  # pause before next action
				return

	print("Enemy found no useful actions.")

func _get_leader_pos(owner: int) -> Vector2i:
	for pos in units.keys():
		var u: UnitData = units[pos]
		if u.is_leader and u.owner == owner:
			return pos
	return Vector2i(-1, -1)

func log_message(msg: String, color: Color = Color.WHITE) -> void:
	if not battle_log:
		return
	battle_log.append_text("[color=" + color.to_html(false) + "]" + msg + "[/color]\n")
	battle_log.scroll_to_line(battle_log.get_line_count() - 1)


func _on_log_button_pressed() -> void:
	print("Log button pressed!")  # <--- Add this
	var log = $UI/VBoxContainer/BattleLogLabel

	var tween = create_tween()
	if log.visible:
		tween.tween_property(log, "modulate:a", 0.0, 0.25)
		await tween.finished
		log.visible = false
	else:
		log.visible = true
		log.modulate.a = 0.0
		tween.tween_property(log, "modulate:a", 1.0, 0.25)
		
func _update_essence_labels(prev_player: int = -1, prev_enemy: int = -1):
	# 🔹 Safety: skip if UI hasn't loaded yet
	if player_essence_label == null or enemy_essence_label == null:
		print("⚠️ Essence labels not ready yet, skipping tween.")
		return

	var player_changed := prev_player != player_essence
	var enemy_changed := prev_enemy != enemy_essence

	player_essence_label.text = "Player Essence: %d" % player_essence
	enemy_essence_label.text = "Enemy Essence: %d" % enemy_essence

	if player_changed:
		var tp = create_tween()
		tp.tween_property(player_essence_label, "modulate", Color(0.6, 1, 0.6), 0.15)
		tp.tween_property(player_essence_label, "modulate", Color(1, 1, 1), 0.25)

	if enemy_changed:
		var te = create_tween()
		te.tween_property(enemy_essence_label, "modulate", Color(1, 1, 0.5), 0.15)
		te.tween_property(enemy_essence_label, "modulate", Color(1, 1, 1), 0.25)

	_refresh_hand_ui()


func _reset_action_flags() -> void:
	acted_this_turn.clear()

	# 🔹 Restore all tiles to normal color
	for pos in units.keys():
		var t = board.get_tile(pos.x, pos.y)
		if t:
			t.set_exhausted(false)


func _has_unit_acted(u: UnitData) -> bool:
	return acted_this_turn.has(u)

func _mark_unit_acted(u: UnitData) -> void:
	acted_this_turn[u] = true

	# 🔹 Dim the tile to show exhaustion
	for pos in units.keys():
		if units[pos] == u:
			var t = board.get_tile(pos.x, pos.y)
			if t:
				t.set_exhausted(true)
			break

func _focus_camera_on(target_pos: Vector3, zoom_mult: float = 0.6, duration: float = 1.0):
	if not camera:
		return
	_is_camera_locked = true  # 🔒 stop clamp and WASD updates during focus

	var t = create_tween()
	var angle = deg_to_rad(45)
	var distance = _zoom_distance * zoom_mult

	var desired_pos = Vector3(
		target_pos.x,
		sin(angle) * distance * 1.5,
		target_pos.z + cos(angle) * distance * 1.5
	)

	t.tween_property(camera, "position", desired_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): 
		_look_at_target(target_pos)
		await get_tree().create_timer(0.3).timeout
		_is_camera_locked = false  # 🔓 unlock when done
	)


func _look_at_target(target_pos: Vector3):
	if camera:
		camera.look_at(target_pos, Vector3.UP)

func _execute_card_ability(unit: UnitData, ability: CardAbility) -> void:
	if not ability:
		return
	ability.execute(self, unit)

func _play_card_sound(sound: AudioStream, position: Vector3 = Vector3.ZERO):
	if not sound:
		return
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	player.stream = sound
	player.global_position = position
	player.unit_size = 5.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.volume_db = -10.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()
	player.connect("finished", Callable(player, "queue_free"))


func _get_unit_tile(u: UnitData) -> Node3D:
	for pos in units.keys():
		if units[pos] == u:
			return board.get_tile(pos.x, pos.y)
	return null

# -------------------------------------------------------------------
# --- UI Visibility Control ---
# -------------------------------------------------------------------
# --- UI Visibility Control ---
func hide_game_ui():
	if not $UI:
		return
	for child in $UI.get_children():
		# Only hide visual UI elements (Controls, CanvasItems, etc.)
		if child is CanvasItem:
			child.visible = false
	print("🎴 Game UI hidden for Collection view.")

func show_game_ui():
	if not $UI:
		return
	for child in $UI.get_children():
		if child is CanvasItem:
			child.visible = true
	print("🎴 Game UI restored after Collection view closed.")

# -------------------------------------------------------------------
# --- Cutscene Control ---
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# --- Battle Intro Cutscene ---
# -------------------------------------------------------------------
func play_intro_cutscene() -> void:
	set_process_input(false)
	_is_camera_locked = true
	fade_rect.modulate.a = 1.0

	await get_tree().process_frame

	# --- Camera start pulled back ---
	var spacing = board.spacing
	var board_center = Vector3(0, 0, 1)
	var board_depth = (BOARD_H - 1) * spacing
	var board_width = (BOARD_W - 1) * spacing
	_zoom_distance = max(board_width, board_depth) * 1.2

	var angle = deg_to_rad(50)
	camera.position = Vector3(0, sin(angle) * _zoom_distance * 1.5, cos(angle) * _zoom_distance * 1.5)
	camera.look_at(board_center, Vector3.UP)

	await _fade(0.0, 1.0)

	# --- Enemy Leader fade-in ---
	var enemy_pos = _get_leader_pos(ENEMY)
	var enemy_tile = board.get_tile(enemy_pos.x, enemy_pos.y)
	_focus_camera_on(enemy_tile.global_position, 0.4, 1.0)
	await get_tree().create_timer(0.5).timeout
	await _fade_in_leader(enemy_pos, "👑 The Enemy Leader has appeared!")

	# --- Player Leader fade-in ---
	var player_pos = _get_leader_pos(PLAYER)
	var player_tile = board.get_tile(player_pos.x, player_pos.y)
	_focus_camera_on(player_tile.global_position, 0.4, 1.0)
	await get_tree().create_timer(0.5).timeout
	await _fade_in_leader(player_pos, "👑 Your Leader enters the battlefield!")

	# --- Pull back to gameplay view ---
	await get_tree().create_timer(0.6).timeout
	_smooth_return_to_origin()
	await get_tree().create_timer(1.2).timeout

	_is_camera_locked = false
	set_process_input(true)
	log_message("⚔️ The battle begins!")

# --- Helper function to fade in a leader card mesh ---
func _fade_in_leader(pos: Vector2i, label: String):
	var tile = board.get_tile(pos.x, pos.y)
	if not tile or not tile.has_node("CardMesh"):
		return
	var mesh = tile.get_node("CardMesh")

	# Duplicate the material so we can adjust transparency independently
	var mat = mesh.get_surface_override_material(0)
	if mat == null:
		mat = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, mat)
	else:
		mat = mat.duplicate()
		mesh.set_surface_override_material(0, mat)

	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var color = mat.albedo_color
	color.a = 0.0
	mat.albedo_color = color

	# Animate position + fade in alpha
	var start_pos = mesh.position
	mesh.position = start_pos - Vector3(0, 0.3, 0)

	var tween = create_tween()
	tween.tween_property(mesh, "position", start_pos, 1.2).set_trans(Tween.TRANS_SINE)

	# ✅ FIX: define callback as variable
	var log_callback := func():
		log_message(label)
	tween.tween_callback(log_callback)

	# Fade-in alpha manually
	for step in range(0, 12):
		await get_tree().create_timer(0.1).timeout
		color.a = float(step) / 12.0
		mat.albedo_color = color
