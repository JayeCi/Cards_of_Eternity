extends Node3D

@export var min_intensity: float = 0.0
@export var max_intensity: float = 1.1
@export var flicker_speed: float = 0.1
@export var random_offset: float = 0.5
@export var blink_chance: float = 0.05 # 5% chance to "blink off"
@export var enable_flicker: bool = true

@onready var lights: Array = get_children().filter(func(n): return n is OmniLight3D)

var _tween: Tween

func _ready() -> void:
	randomize()
	await get_tree().create_timer(randf_range(0.0, 2.0)).timeout  # random start offset

	if enable_flicker:
		_start_flicker_loop()


func _start_flicker_loop() -> void:
	while enable_flicker:
		var new_energy = randf_range(min_intensity, max_intensity)

		# occasional blink
		if randf() < blink_chance:
			_set_light_energy(0.0)
			await get_tree().create_timer(0.05).timeout

		if _tween:
			_tween.kill()
		_tween = create_tween()

		# 🟢 PARALLEL tweening so all OmniLights flicker together
		for l in lights:
			_tween.parallel().tween_property(l, "light_energy", new_energy, flicker_speed)

		await get_tree().create_timer(flicker_speed + randf_range(0.0, random_offset)).timeout


func _set_light_energy(value: float) -> void:
	for l in lights:
		l.light_energy = value
