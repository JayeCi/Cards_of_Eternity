extends Node2D

@export var node_layer: NodePath
@export var map_core_path: NodePath

var nodes: Array = []
var map_core: MapCore

func _ready():
	var layer = get_node(node_layer)
	map_core = get_node(map_core_path)
	for child in layer.get_children():
		if child is MapNode:
			nodes.append(child)
	queue_redraw()

# If you want the white line to "pulse", keep this. If not, you can remove _process entirely.
func _process(_dt):
	queue_redraw()

func _draw():
	var current := map_core.current_node
	var taken = map_core.get_taken_edges()

	for node in nodes:
		for path in node.connected_nodes:
			var other: MapNode = node.get_node(path)
			if other == null:
				continue

			var key := map_core._edge_key(node, other)

			# Decide visibility & color
			var color: Color
			var a := to_local(node.get_line_anchor())
			var b := to_local(other.get_line_anchor())

			if taken.has(key):
				# TAKEN route → GRAY
				color = Color(0.6, 0.6, 0.6, 1.0)
			elif (node == current or other == current) and current.battle_completed:
				# AVAILABLE from current → WHITE (optionally pulsing)
				color = Color(1, 1, 1, 1)
				# comment out next two lines if you don't want animation
				var pulse := 0.5 + sin(Time.get_ticks_msec() / 300.0) * 0.5
				color.a *= pulse
			else:
				# Unreachable → HIDE
				continue

			draw_line(a, b, color, 4.0, true)
