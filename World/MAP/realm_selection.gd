extends Control

@onready var not_unlocked: Panel = $Not_unlocked
@onready var btn_fire: Button = $GridContainer/FIRE
@onready var btn_earth: Button = $GridContainer/EARTH
@onready var btn_water: Button = $GridContainer/WATER
@onready var btn_wind: Button = $GridContainer/WIND

# Example global state (you can store this in Globals or GameSession)
# Adjust according to your actual system
var unlocked_realms = Globals.unlocked_realms

func _ready() -> void:
	TransitionFade.fade_in()

	# 🔒 Disable buttons for locked realms
	btn_fire.disabled = not unlocked_realms.get("fire", false)
	btn_water.disabled = not unlocked_realms.get("water", false)
	btn_wind.disabled  = not unlocked_realms.get("wind", false)
	btn_earth.disabled = not unlocked_realms.get("earth", false)  # optional if always unlocked

# 🔥 Fire portal
func _on_fire_pressed() -> void:
	if btn_fire.disabled: return
	not_unlocked.visible = true
	await get_tree().create_timer(3.0).timeout
	not_unlocked.visible = false

# 🌍 Earth portal
func _on_earth_pressed() -> void:
	if btn_earth.disabled: return
	await TransitionFade.fade_out()
	GameSession.switch_to_map()

# 💧 Water portal
func _on_water_pressed() -> void:
	if btn_water.disabled: return
	not_unlocked.visible = true
	await get_tree().create_timer(3.0).timeout
	not_unlocked.visible = false

# 🌬️ Wind portal
func _on_wind_pressed() -> void:
	if btn_wind.disabled: return
	not_unlocked.visible = true
	await get_tree().create_timer(3.0).timeout
	not_unlocked.visible = false
