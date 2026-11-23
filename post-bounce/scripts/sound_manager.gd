extends Node

## Synthesized audio engine matching the original Web Audio API chimes, clacks, and fanfare.

var is_muted: bool = false
const SAMPLE_RATE: int = 44100

var chime_notes: Array[float] = [587.33, 659.25, 739.99, 880.0, 987.77, 1174.66]
var chime_idx: int = 0

var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 12

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		audio_players.append(p)

func _get_free_player() -> AudioStreamPlayer:
	for p in audio_players:
		if not p.playing:
			return p
	return audio_players[0]

func toggle_mute() -> bool:
	is_muted = not is_muted
	return is_muted

func play_shoot(power_ratio: float) -> void:
	if is_muted:
		return
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
		# Triangle wave:
		var raw: float = 4.0 * absf(phase - 0.5) - 1.0
		# Envelope
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
	player.play()

func play_bounce(impact_speed: float, bounce_count: int) -> void:
	if is_muted:
		return
	var norm: float = clampf(impact_speed / 700.0, 0.12, 1.0)
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
	player.play()
