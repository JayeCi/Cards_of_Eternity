extends Node

@onready var dialogue_ui = preload("res://UI/dialogue_ui.tscn")

var current_ui: Control = null
var active: bool = false
var queue: Array = []

signal dialogue_started
signal dialogue_ended

func _ready():
	add_to_group("dialogue_manager")

func start_dialogue(lines: Array[String]) -> void:
	if active and current_ui == null:
		active = false

	if active:
		queue.append(lines)
		await dialogue_ended
		return

	active = true
	emit_signal("dialogue_started")

	current_ui = dialogue_ui.instantiate()
	get_tree().root.add_child(current_ui)

	current_ui.finished.connect(Callable(self, "_on_dialogue_finished").bind(lines))

	current_ui.play_dialogue(lines)

	await dialogue_ended   # ✅ wait until we emit dialogue_ended inside _on_dialogue_finished

func _on_dialogue_finished(lines: Array[String]) -> void:
	if current_ui:
		current_ui.hide()
		await get_tree().process_frame
		current_ui.queue_free()
		current_ui = null

	active = false

	# 🔹 emit this so any `await dialogue_ended` resumes
	emit_signal("dialogue_ended")

	# Chain queued dialogues if any
	if queue.size() > 0:
		var next: Array[String] = queue.pop_front()
		await start_dialogue(next)
