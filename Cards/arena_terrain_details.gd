extends Control
class_name ArenaTerrainDetails

@onready var art: TextureRect = $MarginContainer/VBoxContainer/PanelContainer/MarginContainer/TextureRect
@onready var name_label: Label = $MarginContainer/VBoxContainer/PanelContainer/MarginContainer/NameLabel


func show_terrain(terrain_type: String) -> void:
	var texture: Texture2D = null
	if Engine.has_singleton("TerrainTextures"):
		var tman = Engine.get_singleton("TerrainTextures")
		texture = tman.TERRAIN_TEXTURES.get(terrain_type, null)

	# ✅ Optional: fallback dynamic load
	if texture == null:
		var path = "res://UI/Terrains/%s.png" % terrain_type.to_lower()
		if ResourceLoader.exists(path):
			texture = load(path)

	if texture:
		art.texture = texture
		name_label.text = terrain_type
		visible = true
		modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.25)
	else:
		hide_terrain()

func hide_terrain() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	visible = false
