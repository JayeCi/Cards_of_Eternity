extends CanvasLayer
class_name FusionEffect2D

@export var duration := 1.8
@export var swirl_radius := 180.0
@export var swirl_speed := 18.0
@export var particle_count := 30

@onready var root := $Root
@onready var tex_a := $Root/TextureRectA
@onready var tex_b := $Root/TextureRectB
@onready var flash := $Root/TextureRectFlash
@onready var fusion_text := $Root/FusionText
@onready var audio := $AudioStreamPlayer

var _elapsed := 0.0
var _center := Vector2.ZERO
var _started := false
var _particles: Array = []
var _particle_data: Array = []

func start(art_a: Texture2D, art_b: Texture2D, fusion_name: String):
	tex_a.texture = art_a
	tex_b.texture = art_b
	_center = get_viewport().get_visible_rect().size * 0.5

	# Root is already centered via anchors, no need to set position
	_started = true
	flash.modulate.a = 0.0
	_elapsed = 0.0

	# Create background overlay for dramatic effect
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = -1
	root.add_child(overlay)

	# Fade in dark overlay
	#var overlay_tween = create_tween()
	#overlay_tween.tween_property(overlay, "color:a", 0.5, 0.3)

	# Create energy particles
	_create_particles()

	# Cards are already centered via anchors, just set their offset positions
	# Start with cards entering from far sides (using offset, not position)
	tex_a.offset_left = -300 - 90
	tex_a.offset_right = -300 + 90
	tex_b.offset_left = 300 - 90
	tex_b.offset_right = 300 + 90

	tex_a.scale = Vector2(0.6, 0.6)
	tex_b.scale = Vector2(0.6, 0.6)
	tex_a.modulate = Color(1.0, 0.9, 0.5)
	tex_b.modulate = Color(0.5, 0.9, 1.0)

	# Card entrance animation - animate to start positions
	var enter_tween = create_tween()
	enter_tween.set_parallel(true)
	enter_tween.tween_property(tex_a, "offset_left", -swirl_radius - 90, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(tex_a, "offset_right", -swirl_radius + 90, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(tex_b, "offset_left", swirl_radius - 90, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(tex_b, "offset_right", swirl_radius + 90, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	audio.play()
	set_process(true)

func _create_particles() -> void:
	for i in range(particle_count):
		var particle = ColorRect.new()
		particle.custom_minimum_size = Vector2(6, 6)
		particle.color = Color(1.0, 0.8 + randf() * 0.2, 0.3 + randf() * 0.4)
		particle.modulate.a = 0.0
		particle.z_index = 50
		# Anchor to center so position is relative to root center
		particle.anchor_left = 0.5
		particle.anchor_top = 0.5
		particle.anchor_right = 0.5
		particle.anchor_bottom = 0.5
		particle.grow_horizontal = Control.GROW_DIRECTION_BOTH
		particle.grow_vertical = Control.GROW_DIRECTION_BOTH
		root.add_child(particle)
		_particles.append(particle)

		# Store particle data
		_particle_data.append({
			"angle": randf() * TAU,
			"speed": 2.0 + randf() * 4.0,
			"radius": 50.0 + randf() * 100.0,
			"scale_base": 0.5 + randf() * 0.5
		})

func _process(delta: float) -> void:
	if not _started:
		return

	_elapsed += delta
	var t := _elapsed / duration

	if t >= 1.0:
		# Final dramatic flash
		flash.modulate = Color(1.5, 1.5, 1.3, 1.0)
		var flash_tween = create_tween()
		flash_tween.tween_property(flash, "modulate:a", 0.0, 0.3)

		# Fade out everything
		var fade := create_tween()
		fade.tween_property(root, "modulate:a", 0.0, 0.3)
		await fade.finished
		queue_free()
		return

	# Smooth acceleration curve for more professional feel
	var ease_t = ease(t, -2.0)  # Exponential ease-in for acceleration

	# Spiral motion with acceleration
	var angle := swirl_speed * _elapsed * (1.0 + t * 2.0)  # Accelerating rotation
	var radius = swirl_radius * (1.0 - ease_t * ease_t)  # Quadratic ease-in

	var pos_a = Vector2(cos(angle), sin(angle)) * radius
	var pos_b = Vector2(cos(angle + PI), sin(angle + PI)) * radius

	# Update offset positions (cards are center-anchored)
	tex_a.offset_left = pos_a.x - 90
	tex_a.offset_right = pos_a.x + 90
	tex_a.offset_top = pos_a.y - 125
	tex_a.offset_bottom = pos_a.y + 125

	tex_b.offset_left = pos_b.x - 90
	tex_b.offset_right = pos_b.x + 90
	tex_b.offset_top = pos_b.y - 125
	tex_b.offset_bottom = pos_b.y + 125

	# Dynamic rotation that accelerates
	tex_a.rotation = angle * 1.5
	tex_b.rotation = -angle * 1.5

	# Scale cards as they approach center - grow then shrink
	var scale_factor = 1.2
	if t < 0.5:
		scale_factor = 1.2 + t * 0.8  # Grow
	else:
		scale_factor = 1.6 - (t - 0.5) * 2.4  # Shrink rapidly

	tex_a.scale = Vector2(scale_factor, scale_factor)
	tex_b.scale = Vector2(scale_factor, scale_factor)

	# Color transition - blend from colored to white
	var color_blend = t * t  # Quadratic for smooth transition
	tex_a.modulate = Color(1.0, 0.9 + 0.1 * color_blend, 0.5 + 0.5 * color_blend, 1.0)
	tex_b.modulate = Color(0.5 + 0.5 * color_blend, 0.9 + 0.1 * color_blend, 1.0, 1.0)

	# Energy flash pulses - multiple peaks for drama
	var flash_pulse = 0.0
	if t < 0.3:
		flash_pulse = sin(t * PI / 0.3) * 0.3
	elif t > 0.7:
		flash_pulse = pow((t - 0.7) / 0.3, 2.0) * 1.2  # Dramatic final flash

	flash.modulate = Color(1.3, 1.2, 0.9, flash_pulse)

	# Animate particles in spiral
	for i in range(_particles.size()):
		var particle = _particles[i]
		if not is_instance_valid(particle):
			continue

		var data = _particle_data[i]
		var particle_angle = data.angle + _elapsed * data.speed
		var particle_radius = data.radius * (1.0 - ease_t * 0.8)

		var particle_pos = Vector2(cos(particle_angle), sin(particle_angle)) * particle_radius
		# Position relative to Root center (which is screen center)
		particle.offset_left = particle_pos.x - 3
		particle.offset_top = particle_pos.y - 3
		particle.offset_right = particle_pos.x + 3
		particle.offset_bottom = particle_pos.y + 3

		# Fade in then out
		var particle_alpha = 0.0
		if t < 0.2:
			particle_alpha = t / 0.2
		elif t > 0.8:
			particle_alpha = (1.0 - t) / 0.2
		else:
			particle_alpha = 1.0

		particle.modulate.a = particle_alpha * 0.8

		# Pulse particle size
		var pulse = sin(_elapsed * 8.0 + i) * 0.5 + 1.0
		var particle_scale = data.scale_base * pulse
		particle.scale = Vector2(particle_scale, particle_scale)

		# Color shift particles over time
		particle.color = Color(1.0, 0.8 + sin(_elapsed * 3.0 + i) * 0.2, 0.3 + cos(_elapsed * 4.0 + i) * 0.3)
