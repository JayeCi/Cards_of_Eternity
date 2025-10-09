extends Control

@export var popup_scene: PackedScene = preload("res://Cards/Utilities/card_pickup_popup.tscn")

@onready var popup_container: VBoxContainer = $PopupContainer

const POPUP_LIFETIME := 2.5

func show_card(card: CardData) -> void:
	if not popup_scene or not card:
		return

	var popup = popup_scene.instantiate()
	popup_container.add_child(popup)
	popup.show_card(card)

	# Optional: fade/slide-in animation
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.9, 0.9)
	var t = create_tween()
	t.tween_property(popup, "modulate:a", 1.0, 0.25)
	t.tween_property(popup, "scale", Vector2(1, 1), 0.25)

	# Cleanup after lifetime (non-blocking)
	_cleanup_popup(popup)


func _cleanup_popup(popup: Control) -> void:
	await get_tree().create_timer(POPUP_LIFETIME).timeout
	if is_instance_valid(popup):
		# Fade out before freeing
		var t = create_tween()
		t.tween_property(popup, "modulate:a", 0.0, 0.25)
		await t.finished
		popup.queue_free()
