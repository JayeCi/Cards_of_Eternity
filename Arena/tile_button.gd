# res://battle/tile_button.gd
extends Button
class_name TileButton

@export var x:int
@export var y:int

@onready var art_sprite = $Art  # or whatever node displays the image

var occupant = null  # UnitData (we'll add in Step 2)
var passable := true
var highlighted := false

@onready var art: TextureRect = $Art
@onready var badge: Label = $Badge

func set_art(tex: Texture2D):
	if art_sprite:
		art_sprite.texture = tex
		art_sprite.rotation_degrees = 0  # reset rotation each time


func set_highlight(on: bool, text: String = "") -> void:
	highlighted = on
	badge.text = text
	modulate = Color(1.1, 1.1, 1.0) if on else Color(1, 1, 1)


func clear() -> void:
	occupant = null
	set_art(null)
	badge.text = ""
	set_highlight(false)
