extends Node
class_name MapAudio3D

# Audio players
var ambient_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer

# Sound effect references (to be loaded)
var sounds := {
	"node_click": null,
	"node_hover": null,
	"player_move": null,
	"player_arrive": null,
	"node_reveal": null,
	"portal_activate": null
}

func _ready():
	setup_audio_players()
	# Load sound effects if they exist
	# load_sound_effects()

func setup_audio_players():
	"""Create audio stream players for different audio types"""

	# Ambient audio (loops)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "SFX"
	add_child(ambient_player)

	# SFX audio (one-shots)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "SFX"
	add_child(sfx_player)

	# Music audio (loops)
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)

func load_sound_effects():
	"""Load sound effect files"""
	# TODO: Load actual sound files when available
	# Example:
	# sounds["node_click"] = load("res://Audio/Sound FX/node_click.wav")
	pass

func play_ambient(stream: AudioStream, volume_db: float = -10.0):
	"""Play ambient sound (looping)"""
	if ambient_player and stream:
		ambient_player.stream = stream
		ambient_player.volume_db = volume_db
		ambient_player.play()

func play_music(stream: AudioStream, volume_db: float = -15.0):
	"""Play background music (looping)"""
	if music_player and stream:
		music_player.stream = stream
		music_player.volume_db = volume_db
		music_player.play()

func play_sfx(sound_name: String, volume_db: float = 0.0):
	"""Play a sound effect by name"""
	if sfx_player and sounds.has(sound_name) and sounds[sound_name]:
		sfx_player.stream = sounds[sound_name]
		sfx_player.volume_db = volume_db
		sfx_player.play()

func play_node_click():
	"""Play node click sound"""
	play_sfx("node_click", -5.0)

func play_node_hover():
	"""Play node hover sound"""
	play_sfx("node_hover", -10.0)

func play_player_move():
	"""Play player movement sound"""
	play_sfx("player_move", -5.0)

func play_player_arrive():
	"""Play player arrival sound"""
	play_sfx("player_arrive", 0.0)

func play_node_reveal():
	"""Play node reveal sound"""
	play_sfx("node_reveal", -5.0)

func play_portal_activate():
	"""Play portal activation sound"""
	play_sfx("portal_activate", 0.0)

func stop_ambient():
	"""Stop ambient sound"""
	if ambient_player:
		ambient_player.stop()

func stop_music():
	"""Stop music"""
	if music_player:
		music_player.stop()

func set_ambient_volume(volume_db: float):
	"""Set ambient volume"""
	if ambient_player:
		ambient_player.volume_db = volume_db

func set_music_volume(volume_db: float):
	"""Set music volume"""
	if music_player:
		music_player.volume_db = volume_db

func set_sfx_volume(volume_db: float):
	"""Set SFX volume"""
	if sfx_player:
		sfx_player.volume_db = volume_db
