extends TextureButton
signal node_selected(node)

@export var encounter_type: String = "battle"
@export var next_nodes: Array[NodePath] = []  # manually set in the editor!

func _ready() -> void:
	connect("pressed", Callable(self, "_on_pressed"))

func _on_pressed() -> void:
	emit_signal("node_selected", self)
