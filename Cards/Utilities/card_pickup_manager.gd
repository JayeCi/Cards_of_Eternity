extends Control

@export var popup_scene: PackedScene = preload("res://Cards/Utilities/card_pickup_popup.tscn")
@onready var popup_container: Control = $PopupContainer

const POPUP_LIFETIME := 5
const POPUP_SPACING := 60.0
const POPUP_DELAY := 0.5  # 🕐 short delay between multiple cards

# ------------------------------------------------------------------
# 🟩 Public: show one or more cards
# ------------------------------------------------------------------
func show_card(cards: Array[CardData]) -> void:
	if cards.is_empty():
		return
	for i in range(cards.size()):
		var card = cards[i]
		await _show_single_card(card)
		await get_tree().create_timer(POPUP_DELAY).timeout  # stagger slightly

# ------------------------------------------------------------------
# 🟩 Internal: single popup
# ------------------------------------------------------------------
func _show_single_card(card: CardData) -> void:
	if not popup_scene or not card:
		return

	var popup := popup_scene.instantiate()
	popup_container.add_child(popup)

	popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.9, 0.9)

	# Offset stack
	var index := popup_container.get_child_count() - 1
	popup.position = Vector2(0, index * POPUP_SPACING)

	popup.show_card(card)

	var t_in := create_tween()
	t_in.tween_property(popup, "modulate:a", 1.0, 0.25)
	t_in.tween_property(popup, "scale", Vector2.ONE, 0.25)

	_run_fade_out(popup)

func _run_fade_out(popup: Control) -> void:
	await get_tree().create_timer(POPUP_LIFETIME).timeout
	if not is_instance_valid(popup):
		return

	var t_out := create_tween()
	t_out.tween_property(popup, "modulate:a", 0.0, 0.25)
	t_out.tween_property(popup, "scale", Vector2(0.9, 0.9), 0.25)
	await t_out.finished

	if is_instance_valid(popup):
		popup.queue_free()
