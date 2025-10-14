# File: arena_battle.gd
extends Node
class_name ArenaBattle

var core: ArenaCore
var board: Node3D
var ui: ArenaUI
var cam: ArenaCamera

var hovered_tile: Node3D = null

func init_battle(core_ref: ArenaCore) -> void:
	core = core_ref
	board = core.board
	ui = core.get_node("UISystem")
	cam = core.get_node("CameraSystem")
	
func _input(event):
	if event.is_action_pressed("cancel_action"):
		_on_cancel_card_drag()


func _process(_dt: float) -> void:
	_update_hover()
	_update_ghost_position()

# -----------------------------
# HOVER & HIGHLIGHT
# -----------------------------
func _update_hover() -> void:
	var result = cam.ray_pick(get_viewport().get_mouse_position())
	var tile: Node3D = null
	if result:
		var node = result.collider
		if node is CollisionShape3D or node is StaticBody3D:
			node = node.get_parent()
		if node and node.has_method("set_highlight"): tile = node

	if hovered_tile and hovered_tile != tile:
		hovered_tile.set_highlight(false)
		hovered_tile = null
		ui.hide_hover()

	if tile:
		tile.set_highlight(true, "★" if core.dragging_card != null else "")

		hovered_tile = tile
		#ui.show_hover_for_tile(tile)
		if core.dragging_card:
			ui.move_ghost_over(tile)

	# also tell core about current tile
	core.hovered_tile = hovered_tile

func _update_ghost_position() -> void:
	# ghost is moved in UI helper; here only default when no tile
	if not core.dragging_card or not ui.ghost_card.visible: return
	if not hovered_tile:
		var mpos = get_viewport().get_mouse_position()
		var from = core.camera.project_ray_origin(mpos)
		var dir = core.camera.project_ray_normal(mpos)
		var default_pos = from + dir * 5.0
		ui.ghost_card.position = default_pos

func clear_highlights() -> void:
	for y in core.BOARD_H:
		for x in core.BOARD_W:
			var t = board.get_tile(x, y)
			if t: t.set_highlight(false)

func show_valid_summon_tiles():
	var leader_pos = core.get_leader_pos(core.PLAYER)
	var tiles_to_highlight: Array = []

	for y in range(core.BOARD_H):
		for x in range(core.BOARD_W):
			var tile = core.board.get_tile(x, y)
			if not tile: continue
			var dist = Vector2i(x, y).distance_to(leader_pos)
			if dist == 1 and tile.occupant == null:
				tiles_to_highlight.append(tile)

	for tile in tiles_to_highlight:
		tile.summon_highlight = true
		tile.set_highlight(true)
		
func clear_summon_highlights():
	for tile in core.board.tiles.values():
		if tile.summon_highlight:
			tile.summon_highlight = false
			if not tile.highlighted:
				tile.set_highlight(false)

# -----------------------------
# BOARD INTERACTION
# -----------------------------
func on_board_click(screen_pos: Vector2) -> void:
	var result = cam.ray_pick(screen_pos)
	if not result: return
	var node = result.collider
	while node and (not node.has_meta("tile_marker")):
		node = node.get_parent()
	if not node: return

	var tile = node
	match core.phase:
		core.Phase.SUMMON_OR_MOVE:
			if tile.occupant and tile.occupant.owner == core.PLAYER:
				if not core.can_unit_act(tile.occupant):
					core._log("⏳ That unit already acted this turn."); return
				core.selected_pos = Vector2i(tile.x, tile.y)
				_show_move_targets(core.selected_pos)
				core._set_phase(core.Phase.SELECT_MOVE_TARGET)
				core._update_phase_ui()
		core.Phase.SELECT_MOVE_TARGET:
			if tile.highlighted:
				await _move_or_battle(core.selected_pos, Vector2i(tile.x, tile.y))
				clear_highlights()
				core.selected_pos = Vector2i(-1,-1)
				core._set_phase(core.Phase.SUMMON_OR_MOVE)
				core._update_phase_ui()

func _show_move_targets(from: Vector2i) -> void:
	clear_highlights()
	var src = board.get_tile(from.x, from.y)
	if not src or not src.occupant: return
	if not core.can_unit_act(src.occupant): return

	var range := core.BASE_MOVE_RANGE
	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var dist = abs(dx) + abs(dy)
			if dist == 0 or dist > range: continue
			var p = from + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= core.BOARD_W or p.y >= core.BOARD_H: continue
			var t = board.get_tile(p.x, p.y)
			if t and (t.occupant == null or t.occupant.owner != core.PLAYER):
				t.set_highlight(true, "•" if t.occupant == null else "⚔")


# -----------------------------
# PLACE / MOVE / BATTLE
# -----------------------------
func place_unit(card: CardData, pos: Vector2i, owner: int, mode: int, mark_acted := true) -> void:
	var u := UnitData.new().init_from_card(card, owner)
	u.mode = mode
	core.units[pos] = u
	var tile = board.get_tile(pos.x, pos.y)
	tile.set_occupant(u)


	match u.mode:
		UnitData.Mode.ATTACK:
			tile.set_art(card.art, owner == core.ENEMY)

			if card.ability and card.ability.trigger == "on_summon":
				core._execute_card_ability(u, card.ability)
		UnitData.Mode.DEFENSE:
			tile.set_art(card.art, owner == core.ENEMY)

			if tile.has_node("CardMesh"):
				var mesh = tile.get_node("CardMesh")
				mesh.rotation_degrees.y = 90
				mesh.position = Vector3(0, mesh.position.y, 0)  # recenters in case rotation shifts it
				mesh.position.x = -0.5
				mesh.position.z = 0.0

		UnitData.Mode.FACEDOWN:
			tile.set_art(core.CARD_BACK)
			if tile.has_node("CardMesh"):
				tile.get_node("CardMesh").rotation_degrees.y = 0

	# set badge for ownership
	tile.set_badge_text("P" if owner == core.PLAYER else "E")

	if mark_acted:
		core.mark_unit_acted(u)

	# sounds
	_play_card_sound(core.CARD_MOVE_SOUND, tile.global_position)
	_play_card_sound(card.place_sound, tile.global_position)

	# apply passive if needed
	if card.ability and card.ability.trigger == "on_passive":
		apply_passive_effect(u, card.ability)

func _move_or_battle(from: Vector2i, to: Vector2i) -> void:
	var src = board.get_tile(from.x, from.y)
	var dst = board.get_tile(to.x, to.y)
	if not src or not dst: return
	var attacker: UnitData = src.occupant
	if not attacker: return
		# 🚫 Prevent attacking or moving onto itself
	if from == to:
		core._log("⚠️ You can’t attack your own tile!", Color(1, 0.6, 0.4))
		return

	if not core.can_unit_act(attacker):
		core._log("⏳ That unit already acted this turn."); return

	# distance rule
	var dist = abs(to.x - from.x) + abs(to.y - from.y)
	if dist > core.BASE_MOVE_RANGE:
		core._log("⚠️ You can only move 1 tile per turn!", Color(1, 0.6, 0.4)); return

	if dst.occupant == null:
		# MOVE
		dst.set_occupant(attacker)
		_play_card_sound(core.CARD_MOVE_SOUND, dst.global_position)
		dst.set_art(
	attacker.card.art if attacker.mode != UnitData.Mode.FACEDOWN else core.CARD_BACK,
	attacker.owner == core.ENEMY
)

		dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")

		src.clear()
		core.units.erase(from)
		core.units[to] = attacker
		core.mark_unit_acted(attacker)
		return

	# BATTLE
	var defender: UnitData = dst.occupant
	if attacker.mode == UnitData.Mode.FACEDOWN:
		attacker.mode = UnitData.Mode.ATTACK
		await _flip_faceup(board.get_tile(from.x, from.y), attacker.card.art)
		core._log("🔄 %s was revealed in attack mode!" % attacker.card.name, Color(1,1,0.6))

	if defender.mode == UnitData.Mode.FACEDOWN:
		defender.mode = UnitData.Mode.DEFENSE
		await _flip_faceup(board.get_tile(to.x, to.y), defender.card.art)
		core._log("❗ %s was revealed!" % defender.card.name, Color(1,0.9,0.7))

	var result: String = await _play_3d_battle(attacker, defender)

	match result:
		"attacker_wins":
			_kill_unit(defender)
			dst.set_occupant(attacker)
			dst.set_art(
	attacker.card.art if attacker.mode != UnitData.Mode.FACEDOWN else core.CARD_BACK,
	attacker.owner == core.ENEMY
)
			dst.set_occupant(attacker)
			dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")

			src.clear()
			core.units.erase(from)
			core.units[to] = attacker
			core.mark_unit_acted(attacker)

		"defender_wins":
			_kill_unit(attacker)
		"both_destroyed":
			_kill_unit(defender)
			_kill_unit(attacker)
		"both_survive", "leader_damaged":
			dst.flash()
			core.mark_unit_acted(attacker)

	# final safety
	if dst.occupant and dst.occupant.current_def <= 0: _kill_unit(dst.occupant)
	if attacker and attacker.current_def <= 0: _kill_unit(attacker)
	
func _on_cancel_card_drag():
	if core.dragging_card:
		# Hide the ghost
		if ui and ui.ghost_card:
			ui.ghost_card.visible = false

		# Return the card to the player hand (depends on your UI system)
		if ui and core.dragging_card:
			ui.return_card_to_hand(core.dragging_card)

		# Clear drag reference
		core.dragging_card = null

		# Reset highlights and hover
		clear_highlights()
		hovered_tile = null
		ui.hide_hover()

		core._log("🌀 Card placement canceled.", Color(0.8, 0.8, 1))

func _fizzle_out(sprite: Sprite3D) -> void:
	if not sprite: return
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector3.ZERO, 0.3)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	await tw.finished

# -----------------------------
# COMBAT RESOLUTION (no negatives)
# -----------------------------
func resolve_battle(att: UnitData, defn: UnitData) -> String:
	var a := att.current_atk
	var d := defn.current_def
	var def_before := d

	core._log("⚔ Battle! %s (ATK %d) vs %s (ATK %d / DEF %d, Mode=%s)" %
		[att.card.name, a, defn.card.name, defn.current_atk, defn.current_def, str(defn.mode)],
		Color(1,0.9,0.6))

	var att_tile = _get_unit_tile(att)
	if att_tile: _play_card_sound(att.card.attack_sound, att_tile.global_position)

	# Leader damage path
	if defn.is_leader:
		defn.hp = max(defn.hp - a, 0)
		core._log("💥 %s attacks the Leader directly for %d damage!" % [att.card.name, a], Color(1, 0.6, 0.6))
		core.on_leader_damaged(defn.owner, defn.hp)
		if defn.hp <= 0: core.on_leader_defeated(defn.owner)
		return "leader_damaged"

	# Trigger "on_attack"
	if att.card.ability and att.card.ability.trigger == "on_attack":
		core._execute_card_ability(att, att.card.ability)

	# Defender in DEFENSE
	if defn.mode == UnitData.Mode.DEFENSE:
		defn.current_def = max(defn.current_def - a, 0)
		core.card_details_ui.call("refresh_if_showing", defn)
		if a > d:
			core._log("💥 %s breaks through %s’s DEF!" % [att.card.name, defn.card.name], Color(0.7,1,0.7))
			_play_card_sound(defn.card.death_sound)
			return "attacker_wins"
		else:
			core._log("🛡 %s’s DEF reduced from %d → %d" % [defn.card.name, def_before, defn.current_def], Color(0.8,0.8,1))
			_play_card_sound(defn.card.defense_sound)
			if defn.current_atk > 0:
				att.current_def = max(att.current_def - defn.current_atk, 0)
				core.card_details_ui.call("refresh_if_showing", att)
				core._log("↩ %s counterattacks for %d! %s DEF → %d" %
					[defn.card.name, defn.current_atk, att.card.name, att.current_def], Color(1,0.9,0.7))
				if att.current_def <= 0:
					_play_card_sound(att.card.death_sound)
					return "defender_wins"
			return "both_survive"

	# Mutual ATTACK
	if defn.mode == UnitData.Mode.ATTACK and att.mode == UnitData.Mode.ATTACK:
		core._log("🔥 Both monsters attack head-on!", Color(1,0.8,0.5))
		defn.current_def = max(defn.current_def - a, 0)
		att.current_def = max(att.current_def - defn.current_atk, 0)
		core.card_details_ui.call("refresh_if_showing", defn)
		core.card_details_ui.call("refresh_if_showing", att)
		core._log("%s DEF → %d | %s DEF → %d" % [defn.card.name, defn.current_def, att.card.name, att.current_def], Color(1,1,1))
		var attacker_destroyed = att.current_def <= 0
		var defender_destroyed = defn.current_def <= 0
		if attacker_destroyed and defender_destroyed:
			_play_card_sound(att.card.death_sound); _play_card_sound(defn.card.death_sound)
			core._log("💀 Both are destroyed in battle!", Color(1,0.4,0.4)); return "both_destroyed"
		elif defender_destroyed:
			_play_card_sound(defn.card.death_sound)
			core._log("💥 %s destroys %s!" % [att.card.name, defn.card.name], Color(0.7,1,0.7)); return "attacker_wins"
		elif attacker_destroyed:
			_play_card_sound(att.card.death_sound)
			core._log("💀 %s is destroyed!" % att.card.name, Color(1,0.4,0.4)); return "defender_wins"
		else:
			return "both_survive"

	return "both_survive"

# -----------------------------
# PASSIVES / KILL / HELPERS
# -----------------------------
func apply_all_passives() -> void:
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		if u.card.ability and u.card.ability.trigger == "on_passive":
			u.card.ability.execute(core, u)

func apply_passive_effect(unit: UnitData, ability: CardAbility) -> void:
	ability.execute(core, unit)
	unit.set_meta("passive_active", true)

func remove_passive_effect(unit: UnitData, ability: CardAbility) -> void:
	if ability.has_method("remove"): ability.remove(core, unit)

func _kill_unit(u: UnitData) -> void:
	if u == null:
		return

	# Remove passive effects if active
	if u.card and u.card.ability and u.card.ability.trigger == "on_passive":
		remove_passive_effect(u, u.card.ability)

	# Find tile
	var found_pos := Vector2i(-1, -1)
	for pos in core.units.keys():
		if core.units[pos] == u:
			found_pos = pos
			break

	if found_pos == Vector2i(-1, -1):
		core._log("⚠️ Tried to kill a unit not on board: %s" % u.card.name)
		return

	var tile = core.board.get_tile(found_pos.x, found_pos.y)
	if not tile:
		return

	# Fade out & clear mesh
	if tile.has_node("CardMesh"):
		var mesh = tile.get_node("CardMesh")
		var tw = create_tween()
		tw.tween_property(mesh, "modulate:a", 0.0, 0.3)
		tw.tween_property(mesh, "scale", mesh.scale * 0.5, 0.3)
		await tw.finished

	tile.clear()
	core.units.erase(found_pos)
	core.card_details_ui.call("hide_card")
	core._log("💀 %s was destroyed." % u.card.name, Color(1, 0.4, 0.4))

func clear_exhausted_tiles() -> void:
	for pos in core.units.keys():
		var t = board.get_tile(pos.x, pos.y)
		if t: t.set_exhausted(false)

func set_exhausted_for_unit(u: UnitData, exhausted: bool) -> void:
	for pos in core.units.keys():
		if core.units[pos] == u:
			var t = board.get_tile(pos.x, pos.y)
			if t: t.set_exhausted(exhausted)
			return

func get_leader_pos(owner: int) -> Vector2i:
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		if u.is_leader and u.owner == owner: return pos
	return Vector2i(-1, -1)

func _get_unit_tile(u: UnitData) -> Node3D:
	for pos in core.units.keys():
		if core.units[pos] == u:
			return board.get_tile(pos.x, pos.y)
	return null

# -----------------------------
# CINEMATIC BATTLE (wraps fade + scene)
# -----------------------------
func _play_3d_battle(att: UnitData, defn: UnitData) -> String:
	var result: String = resolve_battle(att, defn)
	await _fade(1.0, 0.25)

	# === CREATE ARENA SCENE ===
	var battle_scene := Node3D.new()
	core.add_child(battle_scene)

	# --- LIGHTING ---
	var ambient := DirectionalLight3D.new()
	ambient.rotation_degrees = Vector3(-45, 30, 0)
	ambient.light_energy = 2.0
	battle_scene.add_child(ambient)

	var spot := OmniLight3D.new()
	spot.light_color = Color(0.3, 0.6, 1.0)
	spot.light_energy = 5.0
	spot.omni_range = 15.0
	battle_scene.add_child(spot)

	# --- CAMERA ---
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 5)
	cam.look_at(Vector3(0, 0.5, 0))
	battle_scene.add_child(cam)

	# --- FLOOR PLATFORM ---
	var floor := MeshInstance3D.new()
	floor.mesh = CylinderMesh.new()
	floor.scale = Vector3(3, 0.2, 3)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.2, 0.25)
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(0.1, 0.2, 0.5)
	floor.material_override = floor_mat
	floor.position.y = -0.2
	battle_scene.add_child(floor)

	# --- ENERGY PILLARS ---
	for i in range(6):
		var pillar := MeshInstance3D.new()
		pillar.mesh = CylinderMesh.new()
		pillar.scale = Vector3(0.05, randf_range(0.8, 1.2), 0.05)
		pillar.position = Vector3(sin(i * PI / 3.0) * 2.5, pillar.scale.y / 2, cos(i * PI / 3.0) * 2.5)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.4, 0.7, 1.0)
		pm.emission_enabled = true
		pm.emission = pm.albedo_color * 2.0
		pillar.material_override = pm
		battle_scene.add_child(pillar)

# --- ATTACKER ---
	var attacker_sprite := Sprite3D.new()
	attacker_sprite.texture = att.card.art
	attacker_sprite.pixel_size = 0.002
	attacker_sprite.scale = Vector3.ONE
	attacker_sprite.position = Vector3(-2.0, 0.5, 0)
	battle_scene.add_child(attacker_sprite)

	# --- DEFENDER ---
	var defender_sprite := Sprite3D.new()
	defender_sprite.texture = defn.card.art
	defender_sprite.pixel_size = 0.002
	defender_sprite.scale = Vector3.ONE
	defender_sprite.position = Vector3(2.0, 0.5, 0)
	battle_scene.add_child(defender_sprite)

	# ✅ Add glowing outlines instead of full tint
	var attacker_glow: Node3D
	var defender_glow: Node3D
	if att.owner == core.PLAYER:
		attacker_glow = _add_card_highlight(attacker_sprite, Color(0.3, 1.0, 0.3))
		defender_glow = _add_card_highlight(defender_sprite, Color(1.0, 0.3, 0.3))
	else:
		attacker_glow = _add_card_highlight(attacker_sprite, Color(1.0, 0.3, 0.3))
		defender_glow = _add_card_highlight(defender_sprite, Color(0.3, 1.0, 0.3))

	# === INTRO CAMERA PAN ===
	var cam_tween = create_tween()
	cam_tween.tween_property(cam, "position:z", 3.5, 0.4)
	await cam_tween.finished
	await get_tree().create_timer(0.2).timeout

	# === ATTACKER CHARGE ===
	var atk_tween = create_tween()
	_play_card_sound(att.card.attack_sound)
	atk_tween.tween_property(attacker_sprite, "position:x", 0.5, 0.35)
	atk_tween.tween_property(cam, "position:x", -0.3, 0.35)
	await atk_tween.finished

	# === IMPACT FLASH + SHAKE ===
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 1)
	ui.get_tree().root.add_child(flash)
	flash.size = get_viewport().size
	var f = create_tween()
	f.tween_property(flash, "modulate:a", 0.0, 0.2)
	await f.finished
	flash.queue_free()

	# Camera shake
	for i in range(6):
		cam.position.x += randf_range(-0.1, 0.1)
		cam.position.y += randf_range(-0.05, 0.05)
		await get_tree().create_timer(0.03).timeout

	# === DEFENDER REACTION ===
	var def_tw = create_tween()
	_play_card_sound(defn.card.defense_sound)
	def_tw.tween_property(defender_sprite, "rotation_degrees:y", randf_range(-15, 15), 0.1)
	def_tw.tween_property(defender_sprite, "scale", Vector3(0.9, 0.9, 0.9), 0.1)
	await def_tw.finished

	# === OUTCOME ===
	match result:
		"attacker_wins":
			await _card_explode(defender_sprite, Color(1, 0.4, 0.4))
		"defender_wins":
			await _card_explode(attacker_sprite, Color(0.6, 0.6, 1.0))
		"both_destroyed":
			await _card_explode(defender_sprite, Color(1, 0.3, 0.3))
			await _card_explode(attacker_sprite, Color(1, 0.3, 0.3))
		"leader_damaged":
			await _card_pulse(attacker_sprite, Color(1, 0.8, 0.4))

	# Optional: fade tint back before removing
	var fade_tint := create_tween()
	fade_tint.tween_property(attacker_sprite, "modulate", Color(1, 1, 1, 1), 0.3)
	fade_tint.tween_property(defender_sprite, "modulate", Color(1, 1, 1, 1), 0.3)

	await get_tree().create_timer(0.3).timeout
	battle_scene.queue_free()
	await _fade(0.0, 0.25)
	return result
	
func _add_card_highlight(sprite: Sprite3D, color: Color) -> Node3D:
	var glow := MeshInstance3D.new()
	glow.mesh = QuadMesh.new()
	glow.scale = Vector3(1.3, 1.3, 1.3) # slightly bigger than the card art
	glow.position = sprite.position - Vector3(0, 0, 0.01) # 👈 push it slightly behind the sprite

	var mat := StandardMaterial3D.new()
	mat.unshaded = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy = 3.0
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.alpha_scissor_threshold = 0.05
	mat.disable_receive_shadows = true
	mat.disable_ambient_light = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # ensures it's visible even when viewed edge-on
	glow.material_override = mat

	# Ensure it’s rendered behind the art
	glow.sorting_offset = -1

	sprite.get_parent().add_child(glow)
	glow.look_at(sprite.global_position, Vector3.UP)

	return glow

func _card_explode(sprite: Sprite3D, color: Color):
	if not sprite:
		return

	var p := GPUParticles3D.new()
	p.amount = 120
	p.lifetime = 1.0
	p.one_shot = true
	p.position = sprite.position

	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, -9.8, 0)
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 8.0
	mat.scale_min = 0.05
	mat.scale_max = 0.1
	mat.angle_min = -15.0
	mat.angle_max = 15.0
	mat.color = color

	# ✅ Set emission shape here (on the material, not the particles node)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2

	# ✅ Add fade-out gradient
	var grad := Gradient.new()
	grad.add_point(0.0, color)
	grad.add_point(1.0, Color(color.r, color.g, color.b, 0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	p.process_material = mat
	p.emitting = true

	sprite.get_parent().add_child(p)
	sprite.visible = false

	await get_tree().create_timer(1.0).timeout
	p.queue_free()

func _card_pulse(sprite: Sprite3D, color: Color):
	if not sprite: return
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", color, 0.15)
	tw.tween_property(sprite, "modulate", Color(1, 1, 1), 0.25)
	await tw.finished

# -----------------------------
# VISUAL HELPERS
# -----------------------------
func _flip_faceup(tile: Node3D, new_texture: Texture2D):
	var mesh = tile.get_node("CardMesh")
	var tw = create_tween()
	tw.tween_property(mesh, "rotation_degrees:y", 90, 0.15)
	await tw.finished
	tile.set_art(new_texture, tile.occupant.owner == core.ENEMY)

	tw = create_tween()
	tw.tween_property(mesh, "rotation_degrees:y", 0, 0.15)
	await tw.finished

func _fade(to_alpha: float, dur: float):
	var rect: ColorRect = core.get_node("UISystem/FadeRect")

	var tw = create_tween()
	tw.tween_property(rect, "modulate:a", to_alpha, dur)
	await tw.finished

func _play_card_sound(sound: AudioStream, position := Vector3.ZERO):
	if not sound: return
	var p := AudioStreamPlayer3D.new()
	core.add_child(p)
	p.stream = sound
	p.global_position = position
	p.unit_size = 5.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.volume_db = -10.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
	p.connect("finished", Callable(p, "queue_free"))
