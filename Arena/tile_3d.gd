extends Node3D
@export var x: int
@export var y: int
var occupant = null
var highlighted = false

@onready var highlight_mesh = $Highlight
@onready var card_sprite = $CardMesh
@onready var mesh = $TileMesh
@onready var label: Label3D = $Badge
@onready var card_mesh: MeshInstance3D = $CardMesh

func _ready():
	set_meta("tile_marker", true)

	# Ensure this tile uses its own unique mesh resource
	if mesh:
		mesh.mesh = mesh.mesh.duplicate()  # ← clone the mesh itself so it's not shared
		
		var base_mat = mesh.mesh.surface_get_material(0)
		if base_mat:
			var mat_copy = base_mat.duplicate()
			mesh.set_surface_override_material(0, mat_copy)

func set_highlight(state: bool, symbol: String = ""):
	highlighted = state
	if label:
		label.text = symbol
		label.visible = state and symbol != ""
	
	if highlight_mesh:
		highlight_mesh.visible = state

func set_art(tex: Texture2D):
	var mat = card_mesh.get_surface_override_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		card_mesh.set_surface_override_material(0, mat)
	mat.albedo_texture = tex
	card_mesh.visible = true
	card_mesh.position.y = 0.05
func set_badge_text(text: String):
	label.text = text

func clear():
	occupant = null
	if card_mesh:
		var mat = card_mesh.get_surface_override_material(0)
		if mat:
			mat.albedo_texture = null
		card_mesh.visible = false

	label.text = ""
	set_highlight(false)

func flash():
	if not has_node("HighlightMesh"):
		return

	var mesh = $HighlightMesh
	var tw = create_tween()
	mesh.visible = true
	mesh.modulate = Color(1, 0.5, 0.5, 0.8)  # reddish flash
	tw.tween_property(mesh, "modulate:a", 0.0, 0.3)
	await tw.finished
	mesh.visible = false
	
func set_exhausted(state: bool):
	if card_mesh:
		var mat = card_mesh.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			card_mesh.set_surface_override_material(0, mat)

		if state:
			mat.albedo_color = Color(0.4, 0.4, 0.4, 0.7)  # darker and semi-transparent
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		else:
			mat.albedo_color = Color(1, 1, 1, 1)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
