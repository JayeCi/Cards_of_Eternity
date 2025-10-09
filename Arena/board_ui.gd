# res://battle/board_ui.gd
extends Control
class_name BoardUI

@export var rows:int = 7
@export var cols:int = 7
@export var tile_scene: PackedScene = preload("res://Arena/tile_button.tscn")

@onready var grid: GridContainer = $Grid
var tiles: Array = []  # 2D [y][x]

signal tile_pressed(tile: TileButton)

func _ready():
	grid.columns = cols
	for j in range(rows):
		var row: Array = []
		for i in range(cols):
			var t: TileButton = tile_scene.instantiate()
			t.x = i
			t.y = j
			t.pressed.connect(_on_tile_pressed.bind(t))
			grid.add_child(t)
			row.append(t)
		tiles.append(row)

func _on_tile_pressed(t: TileButton) -> void:
	emit_signal("tile_pressed", t)

func get_tile(x:int, y:int) -> TileButton:
	return tiles[y][x]

func for_each_tile(cb: Callable) -> void:
	for j in range(rows):
		for i in range(cols):
			cb.call(tiles[j][i])

func clear_highlights() -> void:
	for_each_tile(func(t): t.set_highlight(false))
