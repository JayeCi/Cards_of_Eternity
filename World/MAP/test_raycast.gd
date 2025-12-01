extends Node3D

# Test script to debug raycasting issues
# Attach this to MapScene3D temporarily

var camera: Camera3D

func _ready():
	# Get camera from parent
	camera = get_parent().get_node("MapCamera3D")
	if camera:
		print("✅ Test script found camera: ", camera.name)
	else:
		print("❌ Test script couldn't find camera")

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🔍 Testing raycast from camera...")

		if not camera:
			print("❌ No camera found!")
			# Try to find it again
			camera = get_parent().get_node_or_null("MapCamera3D")
			if not camera:
				print("❌ Still can't find camera after retry")
				return
			else:
				print("✅ Found camera on retry!")

		# Get the ray from the camera
		var mouse_pos = event.position
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

		print("  📍 From: ", from)
		print("  📍 To: ", to)

		# Raycast
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		query.collide_with_bodies = false

		var result = space_state.intersect_ray(query)

		if result:
			print("  ✅ Hit something: ", result.collider.name if result.collider else "unknown")
			if result.collider.has_method("_on_input_event"):
				print("    Has input event method!")
		else:
			print("  ❌ Didn't hit anything")
