extends Node

## Sound & Music Manager
## Synthesizes classic moonlit tones and layers imported SFX & ambient music.

var is_muted: bool = false
const SAMPLE_RATE: int = 44100

var chime_notes: Array[float] = [587.33, 659.25, 739.99, 880.0, 987.77, 1174.66]
var chime_idx: int = 0

var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 16

var music_player: AudioStreamPlayer
var impact_samples: Array[AudioStream] = []
var ui_click_sound: AudioStream
var ui_hover_sound: AudioStream
var release_sound: AudioStream

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		audio_players.append(p)

	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Master"
	music_player.volume_db = -16.0
	add_child(music_player)

	# Load music if present
	var music_path := "res://assets/sfx/music/forest-stroll-mix.ogg"
	if ResourceLoader.exists(music_path):
		var m_stream = load(music_path)
		if m_stream is AudioStream:
			music_player.stream = m_stream
			music_player.play()

	# Load imported Kenney SFX
	var impact_paths: Array[String] = [
		"res://assets/sfx/Impact-Sound/Audio/switch1.ogg",
		"res://assets/sfx/Impact-Sound/Audio/switch2.ogg",
		"res://assets/sfx/Impact-Sound/Audio/switch3.ogg",
		"res://assets/sfx/Impact-Sound/Audio/switch6.ogg",
		"res://assets/sfx/Impact-Sound/Audio/click3.ogg"
	]
	for path in impact_paths:
		if ResourceLoader.exists(path):
			var s = load(path)
			if s is AudioStream:
				impact_samples.append(s)

	var click_path := "res://assets/sfx/UI-Sound/Audio/click1.ogg"
	if ResourceLoader.exists(click_path):
		ui_click_sound = load(click_path)

	var hover_path := "res://assets/sfx/UI-Sound/Audio/rollover1.ogg"
	if ResourceLoader.exists(hover_path):
		ui_hover_sound = load(hover_path)

	var rel_path := "res://assets/sfx/Impact-Sound/Audio/mouserelease1.ogg"
	if ResourceLoader.exists(rel_path):
		release_sound = load(rel_path)

var sfx_volume: float = 1.0
var music_volume: float = 0.8

func _get_free_player() -> AudioStreamPlayer:
	for p in audio_players:
		if not p.playing:
			return p
	return audio_players[0]

func update_volume_settings(p_sfx: float, p_music: float, p_muted: bool) -> void:
	sfx_volume = clampf(p_sfx, 0.0, 1.0)
	music_volume = clampf(p_music, 0.0, 1.0)
	is_muted = p_muted
	if is_instance_valid(music_player):
		music_player.stream_paused = is_muted
		if music_volume <= 0.001:
			music_player.volume_db = -80.0
		else:
			music_player.volume_db = linear_to_db(music_volume) - 12.0

func toggle_mute() -> bool:
	is_muted = not is_muted
	if is_instance_valid(music_player):
		music_player.stream_paused = is_muted
	return is_muted

func play_shoot(power_ratio: float) -> void:
	if is_muted:
		return

	# Layered release sound
	if release_sound:
		var p_sfx := _get_free_player()
		p_sfx.stream = release_sound
		p_sfx.volume_db = -6.0 + power_ratio * 4.0
		p_sfx.pitch_scale = 0.95 + power_ratio * 0.3
		p_sfx.play()

	# Synthesized launch tone
	var duration: float = 0.14
	var total_samples: int = int(SAMPLE_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var f0: float = 150.0 + power_ratio * 95.0
	var f1: float = 68.0
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var freq: float = lerpf(f0, f1, t / duration)
		phase += freq / float(SAMPLE_RATE)
		if phase >= 1.0:
			phase -= 1.0
		var raw: float = 4.0 * absf(phase - 0.5) - 1.0
		var env: float = 1.0 - (t / duration)
		var vol: float = (0.2 + power_ratio * 0.25) * env
		var sample_val: int = int(clampf(raw * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data

	var player := _get_free_player()
	player.stream = stream
	player.volume_db = 0.0
	player.pitch_scale = 1.0
	player.play()

func play_bounce(impact_speed: float, bounce_count: int) -> void:
	if is_muted:
		return

	var norm: float = clampf(impact_speed / 700.0, 0.12, 1.0)

	# 1. Layer imported impact SFX
	if not impact_samples.is_empty():
		var sfx_player := _get_free_player()
		var sfx = impact_samples[randi() % impact_samples.size()]
		sfx_player.stream = sfx
		sfx_player.volume_db = -18.0 + norm * 14.0
		sfx_player.pitch_scale = randf_range(0.88, 1.15)
		sfx_player.play()

	# 2. Synthesized frequency clack
	var pitch_boost: float = minf(bounce_count, 6) * 28.0
	var base_freq: float = 260.0 + norm * 220.0 + pitch_boost

	var duration: float = 0.09
	var total_samples: int = int(SAMPLE_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var phase: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var freq: float = base_freq * (1.0 - (t / duration) * 0.38)
		phase += freq / float(SAMPLE_RATE)
		if phase >= 1.0:
			phase -= 1.0
		var raw: float = sin(phase * TAU)
		var env: float = (1.0 - (t / duration))
		var vol: float = (0.15 + norm * 0.3) * env
		var sample_val: int = int(clampf(raw * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data

	var player := _get_free_player()
	player.stream = stream
	player.volume_db = -2.0
	player.pitch_scale = 1.0
	player.play()

func play_diamond_chime() -> void:
	if is_muted:
		return
	var freq: float = chime_notes[chime_idx % chime_notes.size()]
	chime_idx += 1

	var duration: float = 0.75
	var total_samples: int = int(SAMPLE_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var phase1: float = 0.0
	var phase2: float = 0.0
	var freq2: float = freq * 1.5

	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		phase1 += freq / float(SAMPLE_RATE)
		phase2 += freq2 / float(SAMPLE_RATE)
		if phase1 >= 1.0: phase1 -= 1.0
		if phase2 >= 1.0: phase2 -= 1.0

		var s1: float = sin(phase1 * TAU) * exp(-4.0 * t) * 0.4
		var s2: float = (4.0 * absf(phase2 - 0.5) - 1.0) * exp(-5.5 * t) * 0.15
		var sample_val: int = int(clampf(s1 + s2, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data

	var player := _get_free_player()
	player.stream = stream
	player.volume_db = 2.0
	player.pitch_scale = 1.0
	player.play()

func play_finish_fanfare() -> void:
	if is_muted:
		return
	var chord_notes: Array[float] = [440.0, 554.37, 659.25, 880.0, 987.77]
	for idx in range(chord_notes.size()):
		var delay: float = float(idx) * 0.055
		_play_fanfare_note(chord_notes[idx], delay, idx % 2 == 0)

func _play_fanfare_note(freq: float, delay_sec: float, is_sine: bool) -> void:
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
	if is_muted:
		return

	var duration: float = 1.0
	var total_samples: int = int(SAMPLE_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var phase: float = 0.0
	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		phase += freq / float(SAMPLE_RATE)
		if phase >= 1.0: phase -= 1.0

		var raw: float = sin(phase * TAU) if is_sine else (4.0 * absf(phase - 0.5) - 1.0)
		var env: float = exp(-3.2 * t) * 0.28
		var sample_val: int = int(clampf(raw * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data

	var player := _get_free_player()
	player.stream = stream
	player.volume_db = 1.0
	player.pitch_scale = 1.0
	player.play()

func play_ui_click() -> void:
	if is_muted or not ui_click_sound:
		return
	var p := _get_free_player()
	p.stream = ui_click_sound
	p.volume_db = -4.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

func play_ui_hover() -> void:
	if is_muted or not ui_hover_sound:
		return
	var p := _get_free_player()
	p.stream = ui_hover_sound
	p.volume_db = -10.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

func play_out_of_bounds() -> void:
	if is_muted:
		return

	# Layer imported impact click if available
	if not impact_samples.is_empty():
		var sfx_p := _get_free_player()
		sfx_p.stream = impact_samples[0]
		sfx_p.volume_db = -6.0
		sfx_p.pitch_scale = 0.65
		sfx_p.play()

	# Synthesized descending void drone / fall
	var duration: float = 0.52
	var total_samples: int = int(SAMPLE_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var f0: float = 210.0
	var f1: float = 48.0
	var phase: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var freq: float = lerpf(f0, f1, pow(t / duration, 0.7))
		phase += freq / float(SAMPLE_RATE)
		if phase >= 1.0:
			phase -= 1.0
		var raw: float = sin(phase * TAU) * 0.75 + (4.0 * absf(phase - 0.5) - 1.0) * 0.25
		var env: float = (1.0 - (t / duration)) * exp(-2.2 * t)
		var sample_val: int = int(clampf(raw * env * 0.42, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data

	var player := _get_free_player()
	player.stream = stream
	player.volume_db = 2.0
	player.pitch_scale = 1.0
	player.play()
