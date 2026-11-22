extends Node
## Sound. Autoloaded as "Sfx".
##
## Every sound in the game is made by tools/bake_audio.gd from plain maths
## (sine, noise, envelopes), so there are no third-party samples. This node
## just plays them: a small pool of players for effects and one for music.

const FOLDER := "res://assets/audio/"
const VOICES := 12

var _streams: Dictionary = {}        ## name -> AudioStream (or null when the file is missing)
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _music_name: StringName = &""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	apply_volume()


func apply_volume() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(Config.master_volume, 0.0001)))
	AudioServer.set_bus_mute(master, Config.master_volume <= 0.001)
	if _music:
		_music.volume_db = linear_to_db(maxf(Config.music_volume, 0.0001))


func _stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		var path := FOLDER + String(sound) + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


## Plays a short effect. [param pitch] shifts it, which the drills use to make
## streaks climb in tone.
func play(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()


func music(track: StringName, fade: float = 0.6) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	var stream := _stream(track)
	if _music_tween:
		_music_tween.kill()
	if stream == null:
		_music.stop()
		return
	if stream is AudioStreamWAV:
		# The loop points are set here rather than trusted to the importer.
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", linear_to_db(maxf(Config.music_volume, 0.0001)), fade)


func stop_music(fade: float = 0.5) -> void:
	_music_name = &""
	if _music_tween:
		_music_tween.kill()
	if not _music.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -50.0, fade)
	_music_tween.tween_callback(_music.stop)
