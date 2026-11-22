extends SceneTree
## Makes every sound in the game from plain maths and writes it to
## assets/audio as WAV files. Nothing is sampled or downloaded, so the audio
## is as original as the code.
##
##   godot --headless --path . --script res://dev/bake_audio.gd
##
## Run it again after changing a recipe; the output is committed.

const RATE := 44100
const OUT := "res://assets/audio/"

var _noise := RandomNumberGenerator.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_noise.seed = 20261123
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var started := Time.get_ticks_msec()

	_save("hit", _mix([_tone(880.0, 1500.0, 0.11, 0.9, 30.0, &"sine"), _noise_burst(0.02, 0.35, 0.0, 6000.0)]))
	_save("miss", _mix([_tone(170.0, 80.0, 0.16, 0.9, 16.0, &"sine"), _noise_burst(0.05, 0.25, 900.0, 0.0)]))
	_save("pop", _tone(520.0, 900.0, 0.07, 0.8, 45.0, &"sine"))
	_save("lock", _seq([[660.0, 0.05], [990.0, 0.09]], &"triangle", 26.0, 0.8))
	_save("slip", _tone(520.0, 260.0, 0.12, 0.7, 14.0, &"triangle"))
	_save("tick", _tone(1500.0, 1500.0, 0.03, 0.7, 90.0, &"sine"))
	_save("go", _mix([_tone(990.0, 990.0, 0.14, 0.8, 16.0, &"square"), _tone(1485.0, 1485.0, 0.14, 0.4, 16.0, &"square"), _noise_burst(0.03, 0.3, 0.0, 5000.0)]))
	_save("bad", _mix([_tone(146.0, 110.0, 0.34, 0.6, 7.0, &"saw"), _tone(155.0, 117.0, 0.34, 0.6, 7.0, &"saw"), _noise_burst(0.08, 0.2, 1200.0, 0.0)]))
	_save("good", _mix([_tone(1046.5, 1046.5, 0.3, 0.6, 9.0, &"sine"), _delay(_tone(1568.0, 1568.0, 0.26, 0.5, 9.0, &"sine"), 0.05)]))
	_save("coin", _seq([[987.8, 0.06], [1318.5, 0.3]], &"square", 9.0, 0.5))
	_save("empty", _mix([_noise_burst(0.015, 0.5, 0.0, 3000.0), _tone(300.0, 220.0, 0.03, 0.5, 60.0, &"sine")]))
	_save("shot", _mix([_tone(1300.0, 260.0, 0.13, 0.6, 14.0, &"saw"), _noise_burst(0.05, 0.25, 0.0, 2500.0)]))
	_save("boom", _mix([_tone(120.0, 42.0, 0.42, 1.0, 7.0, &"sine"), _noise_burst(0.22, 0.6, 1400.0, 0.0), _tone(660.0, 990.0, 0.1, 0.3, 22.0, &"sine")]))
	_save("ping", _mix([_tone(1244.5, 1244.5, 0.32, 0.6, 9.0, &"sine"), _delay(_tone(1244.5, 1244.5, 0.25, 0.22, 10.0, &"sine"), 0.13)]))
	_save("heart", _mix([_tone(70.0, 42.0, 0.13, 1.0, 16.0, &"sine"), _delay(_tone(62.0, 38.0, 0.15, 0.8, 14.0, &"sine"), 0.15)]))
	_save("card", _whoosh(0.28))
	_save("stamp", _mix([_tone(95.0, 48.0, 0.28, 1.0, 10.0, &"sine"), _noise_burst(0.04, 0.6, 2500.0, 0.0), _tone(330.0, 330.0, 0.08, 0.25, 30.0, &"square")]))
	_save("count", _tone(660.0, 660.0, 0.13, 0.7, 12.0, &"square"))
	_save("start", _mix([_tone(1320.0, 1320.0, 0.42, 0.55, 6.0, &"square"), _tone(1980.0, 1980.0, 0.42, 0.25, 6.0, &"sine")]))
	_save("reveal", _riser(1.0))
	_save("cheer", _cheer())
	_save("music_run", _music_run(), true)
	_save("music_attract", _music_attract(), true)

	print("audio baked in %.1f s" % (float(Time.get_ticks_msec() - started) / 1000.0))
	quit(0)


# ---- building blocks ----

func _samples(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	return buf


func _wave(kind: StringName, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match kind:
		&"square":
			return 0.7 if p < 0.5 else -0.7
		&"saw":
			return 2.0 * p - 1.0
		&"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
	return sin(p * TAU)


## One note that slides from [param f0] to [param f1] and dies away.
func _tone(f0: float, f1: float, seconds: float, volume: float, decay: float, kind: StringName, attack: float = 0.004) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var phase := 0.0
	var n := buf.size()
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / float(n)
		phase += lerpf(f0, f1, k) / RATE
		var env := exp(-decay * t) * minf(1.0, t / attack) * minf(1.0, (seconds - t) / 0.008)
		buf[i] = _wave(kind, phase) * volume * env
	return buf


## A burst of noise. A low-pass cutoff keeps the low part, a high-pass cutoff
## keeps the high part; pass 0 to skip either.
func _noise_burst(seconds: float, volume: float, lowpass_hz: float, highpass_hz: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var low := 0.0
	var slow := 0.0
	var a_low := 1.0 - exp(-TAU * lowpass_hz / RATE) if lowpass_hz > 0.0 else 1.0
	var a_high := 1.0 - exp(-TAU * highpass_hz / RATE) if highpass_hz > 0.0 else 0.0
	var n := buf.size()
	for i in n:
		var x := _noise.randf_range(-1.0, 1.0)
		low += (x - low) * a_low
		var y := low
		if a_high > 0.0:
			slow += (y - slow) * a_high
			y -= slow
		var k := float(i) / float(n)
		buf[i] = y * volume * (1.0 - k) * (1.0 - k)
	return buf


## Notes one after another: [[frequency, seconds], ...].
func _seq(notes: Array, kind: StringName, decay: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note: Array in notes:
		out.append_array(_tone(float(note[0]), float(note[0]), float(note[1]), volume, decay, kind))
	return out


func _delay(buf: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out := _samples(seconds)
	out.append_array(buf)
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var longest := 0
	for p: PackedFloat32Array in parts:
		longest = maxi(longest, p.size())
	var out := PackedFloat32Array()
	out.resize(longest)
	for p: PackedFloat32Array in parts:
		for i in p.size():
			out[i] += p[i]
	return out


func _add(into: PackedFloat32Array, part: PackedFloat32Array, at_seconds: float, wrap: bool = false) -> void:
	var start := int(at_seconds * RATE)
	var n := into.size()
	for i in part.size():
		var j := start + i
		if j >= n:
			if not wrap:
				return
			j %= n   # tails wrap round so a loop has no seam
		into[j] += part[i]


func _whoosh(seconds: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var low := 0.0
	var n := buf.size()
	for i in n:
		var k := float(i) / float(n)
		var cutoff := lerpf(300.0, 7000.0, k * k)
		low += (_noise.randf_range(-1.0, 1.0) - low) * (1.0 - exp(-TAU * cutoff / RATE))
		buf[i] = low * 0.7 * sin(k * PI)
	return buf


func _riser(seconds: float) -> PackedFloat32Array:
	var buf := _samples(seconds + 0.5)
	var phase := 0.0
	var low := 0.0
	var rise := int(seconds * RATE)
	for i in rise:
		var k := float(i) / float(rise)
		phase += lerpf(180.0, 900.0, k * k) / RATE
		low += (_noise.randf_range(-1.0, 1.0) - low) * 0.25
		buf[i] = (_wave(&"saw", phase) * 0.22 + _wave(&"sine", phase * 2.0) * 0.2 + low * 0.3) * k * k
	_add(buf, _tone(110.0, 45.0, 0.45, 0.9, 7.0, &"sine"), seconds)
	_add(buf, _tone(1318.5, 1318.5, 0.45, 0.35, 6.0, &"sine"), seconds)
	return buf


## A crowd-like swell under a bright major chord.
func _cheer() -> PackedFloat32Array:
	var seconds := 1.6
	var buf := _samples(seconds)
	var low := 0.0
	var slow := 0.0
	var n := buf.size()
	for i in n:
		var t := float(i) / RATE
		var x := _noise.randf_range(-1.0, 1.0)
		low += (x - low) * 0.35
		slow += (low - slow) * 0.02
		var env := minf(1.0, t / 0.18) * exp(-2.2 * maxf(0.0, t - 0.5))
		var flutter := 0.75 + 0.25 * sin(t * 31.0) * sin(t * 7.3)
		buf[i] = (low - slow) * 0.5 * env * flutter
	for f: float in [523.25, 659.25, 783.99, 1046.5]:
		_add(buf, _tone(f, f, 1.1, 0.16, 3.2, &"triangle", 0.02), 0.0)
	return buf


# ---- music ----

func _freq(semitones_from_a4: int) -> float:
	return 440.0 * pow(2.0, float(semitones_from_a4) / 12.0)


## 128 beats a minute, eight bars, A minor: the loop under a run.
func _music_run() -> PackedFloat32Array:
	var beat := 60.0 / 128.0
	var bars := 8
	var buf := _samples(float(bars * 4) * beat)
	# Roots as semitones from A4, two bars each: A, F, C, G.
	var roots: Array[int] = [-24, -28, -21, -26]
	var chords: Array = [[0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7]]
	var kick := _tone(150.0, 46.0, 0.2, 0.9, 14.0, &"sine")
	var hat := _noise_burst(0.035, 0.14, 0.0, 7000.0)
	var clap := _noise_burst(0.13, 0.26, 0.0, 1800.0)
	for b in bars * 4:
		var at := float(b) * beat
		var section := (b / 8) % 4
		var root := roots[section]
		var chord: Array = chords[section]
		_add(buf, kick, at, true)
		_add(buf, hat, at + beat * 0.5, true)
		if b % 2 == 1:
			_add(buf, clap, at, true)
		# Bass: two eighth notes a beat, the second an octave up.
		_add(buf, _tone(_freq(root), _freq(root), beat * 0.45, 0.42, 7.0, &"triangle"), at + beat * 0.5, true)
		_add(buf, _tone(_freq(root + 12), _freq(root + 12), beat * 0.2, 0.2, 12.0, &"triangle"), at + beat * 0.75, true)
		# Arpeggio: four sixteenths a beat, climbing the chord.
		for s in 4:
			var step := (b * 4 + s) % 6
			var tone_index := [0, 1, 2, 1, 2, 0][step] as int
			var octave := 24 if step < 3 else 36
			var f := _freq(root + int(chord[tone_index]) + octave)
			_add(buf, _tone(f, f, beat * 0.24, 0.13, 13.0, &"triangle"), at + float(s) * beat * 0.25, true)
			_add(buf, _tone(f, f, beat * 0.2, 0.05, 13.0, &"triangle"), at + float(s) * beat * 0.25 + beat * 0.75, true)
		# Pad: the chord, held for the two bars.
		if b % 8 == 0:
			for interval: int in chord:
				var f := _freq(root + interval + 24)
				_add(buf, _pad(f, beat * 8.0, 0.045), at, true)
	return buf


## 100 beats a minute, eight bars: calm, for the attract screen.
func _music_attract() -> PackedFloat32Array:
	var beat := 60.0 / 100.0
	var bars := 8
	var buf := _samples(float(bars * 4) * beat)
	var roots: Array[int] = [-24, -28, -21, -26]
	var chords: Array = [[0, 3, 7, 10], [0, 4, 7, 11], [0, 4, 7, 11], [0, 4, 7, 9]]
	var kick := _tone(110.0, 44.0, 0.22, 0.5, 12.0, &"sine")
	for b in bars * 4:
		var at := float(b) * beat
		var section := (b / 8) % 4
		var root := roots[section]
		var chord: Array = chords[section]
		if b % 2 == 0:
			_add(buf, kick, at, true)
		# A slow arpeggio in eighth notes.
		for s in 2:
			var step := (b * 2 + s) % 8
			var tone_index := [0, 2, 1, 3, 2, 1, 3, 2][step] as int
			var f := _freq(root + int(chord[tone_index]) + 24)
			_add(buf, _tone(f, f, beat * 0.9, 0.09, 4.5, &"sine"), at + float(s) * beat * 0.5, true)
		if b % 8 == 0:
			for interval: int in chord:
				_add(buf, _pad(_freq(root + interval + 12), beat * 8.0, 0.05), at, true)
			_add(buf, _tone(_freq(root), _freq(root), beat * 7.5, 0.16, 0.5, &"sine", 0.2), at, true)
	return buf


## A soft held note: two slightly detuned sines with a slow start and end.
func _pad(freq: float, seconds: float, volume: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var n := buf.size()
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.5) * minf(1.0, (seconds - t) / 0.6)
		buf[i] = (sin(TAU * freq * t) + sin(TAU * freq * 1.006 * t) + 0.4 * sin(TAU * freq * 2.0 * t)) * volume * env
	return buf


# ---- output ----

func _save(sound_name: String, samples: PackedFloat32Array, looped: bool = false) -> void:
	# Bring the peak to a fixed level so every sound sits at a known volume.
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := (0.7 if looped else 0.85) / peak
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	var path := OUT + sound_name + ".wav"
	var err := wav.save_to_wav(path)
	print("%-16s %6.2f s  %s" % [sound_name, float(samples.size()) / RATE, "ok" if err == OK else error_string(err)])
