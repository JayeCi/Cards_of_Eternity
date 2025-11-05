extends Area3D

signal tutorial_portal_entered

func _ready():
	monitoring = true
	monitorable = true

func _on_body_entered(body):
	if Globals.tutorial_completed:
		return # ✅ already completed, ignore

	if body.is_in_group("player"):
		emit_signal("tutorial_portal_entered", body)
