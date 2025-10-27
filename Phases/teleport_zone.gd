# File: teleport_zone.gd
extends Area3D

@export var marker_path: NodePath
@export var player_group := "player"
@export var copy_rotation := true
@export var cooldown_sec := 0.25

var _marker: Node3D
@onready var _chime3d: AudioStreamPlayer3D = $DoorChime   # optional; can be AudioStreamPlayer too

func _ready() -> void:
	_marker = get_node_or_null(marker_path)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _marker == null: return
	if player_group != "" and not body.is_in_group(player_group): return

	var now := Time.get_ticks_msec()
	if body.has_meta("tp_until") and now < int(body.get_meta("tp_until")):
		return
	body.set_meta("tp_until", now + int(cooldown_sec * 1000.0))

	# play chime (if present)
	if is_instance_valid(_chime3d) and _chime3d.stream:
		if _chime3d is AudioStreamPlayer3D:
			_chime3d.global_transform.origin = _marker.global_transform.origin
		_chime3d.play()

	# move the player
	if body is Node3D:
		var t = body.global_transform
		t.origin = _marker.global_transform.origin
		if copy_rotation:
			t.basis = _marker.global_transform.basis
		body.set_deferred("global_transform", t)
