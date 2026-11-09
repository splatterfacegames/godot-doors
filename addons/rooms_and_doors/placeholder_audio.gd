class_name PlaceholderAudio
extends RefCounted
## Procedural placeholder sounds so Door.tscn has no asset dependency.

const RATE := 22050


static func creak() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 180.0 + 140.0 * sin(t * 9.0) + 60.0 * t
		phase += TAU * f / RATE
		var env := sin(PI * t / 0.45)
		var s := (sin(phase) * 0.6 + sin(phase * 2.03) * 0.25) * env * 0.5
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func knock() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for hit in 3:
			var dt := t - hit * 0.15
			if dt >= 0.0 and dt < 0.08:
				s += (sin(TAU * 110.0 * dt) * 0.7 + rng.randf_range(-0.3, 0.3)) * exp(-dt * 60.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func latch() -> AudioStreamWAV:
	var n := int(RATE * 0.12)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		var t := float(i) / RATE
		var s := (rng.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 1800.0 * t) * 0.5) * exp(-t * 80.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
