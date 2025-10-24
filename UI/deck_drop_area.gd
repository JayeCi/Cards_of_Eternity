extends Control
class_name DropReceiver

signal card_dropped(pos: Vector2, data)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

	# ✅ Make parent ScrollContainer forward drag & drop properly
	if get_parent() and get_parent() is ScrollContainer:
		var sc := get_parent() as ScrollContainer
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		sc.set_drag_forwarding(
			func(_pos): return null,  # we don’t start drags here
			func(_pos, data): return data is Dictionary and data.has("card_data"),
			func(pos, data): _receive_drop(pos, data)
		)

	print("[DropReceiver] ✅ Ready on", name)
	
func _receive_drop(pos: Vector2, data) -> void:
	if not (data is Dictionary and data.has("card_data")):
		return

	print("[DropReceiver] 🟢 Drop received:", data["card_data"].name, "on", name)
	emit_signal("card_dropped", pos, data)

func _can_drop_data(_pos, data) -> bool:
	if data is Dictionary and data.has("card_data"):
		modulate = Color(0.6, 1.0, 0.6, 0.35) # highlight when valid
		return true
	modulate = Color(1, 1, 1, 1)
	return false

func _drop_data(pos, data) -> void:
	modulate = Color(1, 1, 1, 1)
	if data is Dictionary and data.has("card_data"):
		print("[DropReceiver] 🟢 Dropped:", data["card_data"].name, "on", name)
		emit_signal("card_dropped", pos, data)
