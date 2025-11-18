extends TextureRect

@onready var tween := create_tween().set_loops(0) # 🔁 infinite looping animation


#func _ready():
	#_start_loop_animation()



func _start_loop_animation():
	#tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "rotation_degrees", 2.0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(self, "scale", Vector2(1.0, 1.0), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees", -2.0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
