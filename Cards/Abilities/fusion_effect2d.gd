extends CanvasLayer
class_name FusionEffect2D

@export var duration := 2
@export var swirl_radius := 105.0
@export var swirl_speed := 15.0

@onready var root := $Root
@onready var tex_a := $Root/TextureRectA
@onready var tex_b := $Root/TextureRectB
@onready var flash := $Root/TextureRectFlash
@onready var fusion_text := $Root/FusionText
@onready var audio := $AudioStreamPlayer

var _elapsed := 0.0
var _center := Vector2.ZERO
var _started := false

func start(art_a: Texture2D, art_b: Texture2D, fusion_name: String):
	tex_a.texture = art_a
	tex_b.texture = art_b
	#fusion_text.text = "🧬 " + fusion_name + "!"
	_center = get_viewport().get_visible_rect().size * 0.5

	root.position = _center
	_started = true
	flash.modulate.a = 0.0
	_elapsed = 0.0
	audio.play()
	set_process(true)

func _process(delta: float) -> void:
	if not _started: return
	_elapsed += delta
	var t := _elapsed / duration
	if t >= 1.0:
		# flash and fade out
		var fade := create_tween()
		fade.tween_property(root, "modulate:a", 0.0, 0.4)
		await fade.finished
		queue_free()
		return

	var angle := swirl_speed * _elapsed
	var radius := swirl_radius * (1.0 - t)
	var pos_a := Vector2(cos(angle), sin(angle)) * radius
	var pos_b := Vector2(cos(angle + PI), sin(angle + PI)) * radius

	tex_a.position = pos_a
	tex_b.position = pos_b
	tex_a.rotation = angle
	tex_b.rotation = -angle
	tex_a.modulate.a = 1.0 - t * 0.5
	tex_b.modulate.a = 1.0 - t * 0.5

	# flash pulse
	flash.modulate.a = sin(t * PI) * 0.6
