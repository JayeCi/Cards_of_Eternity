extends Node3D
class_name Tile

@export var x: int
@export var y: int
@export var terrain_type: String = "Stone"

var occupant = null
var highlighted = false
var hover_highlight = false 
var summon_highlight := false  # 🔒 stays visible until explicitly cleared

@onready var highlight_mesh: MeshInstance3D = $Highlight
@onready var card_mesh: MeshInstance3D = $CardMesh
@onready var mesh: MeshInstance3D = $TileMesh
@onready var label: Label3D = $Badge
@onready var hover_area: Area3D = $HoveredArea
@onready var leader_badge: MeshInstance3D = $LeaderBadge

signal hovered(tile)
signal unhovered(tile)

func _ready():
	set_meta("tile_marker", true)
	_apply_terrain_visual()
	
	if hover_area:
		hover_area.mouse_entered.connect(_on_mouse_entered)
		hover_area.mouse_exited.connect(_on_mouse_exited) 
	# --- Ensure unique mesh and material per tile ---
	if mesh and mesh.mesh:
		mesh.mesh = mesh.mesh.duplicate()  # duplicate the mesh resource
		var base_mat := mesh.mesh.surface_get_material(0)
		if base_mat:
			var unique_mat = base_mat.duplicate()
			mesh.set_surface_override_material(0, unique_mat)

	# initialize color
	_apply_terrain_visual()

	if card_mesh:
		card_mesh.visible = false  # invisible until art is set

# --- CORE FUNCTION ---
func set_art(tex: Texture2D, flipped: bool = false) -> void:
	if occupant and occupant.has_method("get"):
		flipped = occupant.owner == 1 if not flipped else flipped

	if not card_mesh:
		return

	if tex == null:
		card_mesh.visible = false
		return

	var mat := card_mesh.get_surface_override_material(0)
	if not mat:
		var base_mat := card_mesh.mesh.surface_get_material(0)
		mat = base_mat.duplicate() if base_mat else StandardMaterial3D.new()
		card_mesh.set_surface_override_material(0, mat)

	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.uv1_scale.y = -1 if flipped else 1

	card_mesh.visible = true
	card_mesh.position.y = 0.05


# --- OTHER VISUAL HELPERS ---
func set_highlight(state: bool, symbol: String = "") -> void:
	highlighted = state
	if label:
		label.text = symbol
		label.visible = state and symbol != ""
	if highlight_mesh:
		highlight_mesh.visible = state


func set_badge_text(text: String) -> void:
	if label:
		label.text = text
		label.visible = text != ""


func clear() -> void:
	if card_mesh:
		card_mesh.visible = false
		card_mesh.scale = Vector3.ONE
	set_badge_text("")
	set_highlight(false)
	occupant = null

	if leader_badge:
		leader_badge.visible = false

func set_occupant(unit: UnitData) -> void:
	occupant = unit

	# Update art if card exists
	if unit and unit.card:
		set_art(unit.card.art, unit.owner == 1)
	else:
		card_mesh.visible = false

	# Show/hide the leader badge
	_update_leader_badge()

func _update_leader_badge() -> void:
	if not leader_badge:
		return

	if occupant and occupant.is_leader:
		leader_badge.visible = true
	else:
		leader_badge.visible = false

func flash() -> void:
	if not highlight_mesh:
		return
	var mat := highlight_mesh.get_surface_override_material(0)
	if not mat:
		var base := highlight_mesh.mesh.surface_get_material(0)
		mat = base.duplicate() if base else StandardMaterial3D.new()
		highlight_mesh.set_surface_override_material(0, mat)

	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0.5)
	mat.emission_energy_multiplier = 4.0
	highlight_mesh.visible = true

	var tw = create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.3)
	await tw.finished

	mat.emission_enabled = false
	mat.emission = Color(0, 0, 0)
	highlight_mesh.visible = false


func set_exhausted(state: bool) -> void:
	if not card_mesh:
		return
	var mat := card_mesh.get_surface_override_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		card_mesh.set_surface_override_material(0, mat)

	if state:
		mat.albedo_color = Color(0.4, 0.4, 0.4, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.albedo_color = Color(1, 1, 1, 1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED


# --- TERRAIN COLOR SYSTEM ---
func set_terrain_type(new_type: String) -> void:
	terrain_type = new_type
	_apply_terrain_visual()

func _apply_terrain_visual() -> void:
	if not mesh:
		return

	# 🚀 Always assign a fresh StandardMaterial3D to prevent shared state
	var mat := StandardMaterial3D.new()
	#mat.unshaded = false
	mat.emission_enabled = true
	mat.roughness = 0.5
	mat.metallic = 0.1
	mesh.set_surface_override_material(0, mat)

	match terrain_type:
		"Stone":
			mat.albedo_color = Color(0.5, 0.5, 0.5)
			mat.emission = Color(0.2, 0.2, 0.25)
		"Grass":
			mat.albedo_color = Color(0.3, 0.8, 0.3)
			mat.emission = Color(0.05, 0.25, 0.05)
		"Lava":
			mat.albedo_color = Color(1.0, 0.3, 0.1)
			mat.emission = Color(1.0, 0.1, 0.0)
			mat.emission_energy_multiplier = 2.0
		"Water":
			mat.albedo_color = Color(0.2, 0.4, 1.0)
			mat.emission = Color(0.1, 0.2, 0.6)
		"Forest":
			mat.albedo_color = Color(0.1, 0.5, 0.2)
			mat.emission = Color(0.0, 0.2, 0.0)
		"Ice":
			mat.albedo_color = Color(0.6, 0.8, 1.0)
			mat.emission = Color(0.4, 0.6, 1.0)
		_:
			mat.albedo_color = Color(0.6, 0.6, 0.6)
			mat.emission = Color(0.2, 0.2, 0.2)

	# Optional: make highlight match terrain hue slightly
	if highlight_mesh:
		var hmat := highlight_mesh.get_surface_override_material(0)
		if not hmat:
			hmat = StandardMaterial3D.new()
			highlight_mesh.set_surface_override_material(0, hmat)
		hmat.albedo_color = mat.albedo_color.lightened(0.4)

func _update_highlight_visibility() -> void:
	if not highlight_mesh:
		return
	
	# Always visible if any highlight type is active
	highlight_mesh.visible = highlighted or hover_highlight or summon_highlight


# 🆕 HOVER BEHAVIOR ---
func _on_mouse_entered() -> void:
	print("Hovered tile:", terrain_type)
	hover_highlight = true
	_update_highlight_visibility()
	emit_signal("hovered", self)
	
func _on_mouse_exited() -> void:
	hover_highlight = false

	# 🧠 Only hide hover highlights if NOT system-marked
	if not highlighted and not summon_highlight and highlight_mesh:
		highlight_mesh.visible = false

	emit_signal("unhovered", self)
