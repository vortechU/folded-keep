extends RefCounted
## Small mono PCM weather beds. Human recordings at the normal asset paths take priority.
## Built once per sound, cached by Audio, with no generators/threads in the playback path.
const RATE := 16000


static func make_sound(name: String) -> AudioStreamWAV:
	if not ["rain", "storm", "thunder", "wind_gust"].has(name):
		return null
	var looping := name == "rain" or name == "storm"
	var duration := 6.0 if looping else 3.8 if name == "thunder" else 2.8
	var count := int(duration * RATE)
	var overlap := int(0.35 * RATE) if looping else 0
	var samples := PackedFloat32Array()
	samples.resize(count + overlap)
	var rng := RandomNumberGenerator.new()
	rng.seed = 74921 + name.hash()
	var soft := 0.0
	var rumble := 0.0
	var deep := 0.0
	var drop := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		soft = lerpf(soft, noise, 0.16)
		rumble = lerpf(rumble, noise, 0.025)
		deep = lerpf(deep, noise, 0.004)
		drop *= 0.94
		if rng.randf() < 0.007:
			drop = rng.randf_range(0.015, 0.09)
		var sample := 0.0
		match name:
			"rain", "storm":
				var swell := 0.85 + 0.15 * sin(TAU * t / duration)
				sample = (soft * 0.28 + noise * 0.035 + drop * noise) * swell
				if name == "storm":
					sample += (rumble * 0.55 + deep * 1.4) * (0.8 + 0.2 * sin(TAU * t / duration))
			"thunder":
				var attack := minf(t / 0.035, 1.0)
				var decay := exp(-t * 1.25) * minf((duration - t) / 0.35, 1.0)
				var cracks := exp(-t * 13.0) + 0.35 * exp(-absf(t - 0.19) * 35.0)
				sample = (rumble * 2.0 + deep * 4.0 + soft * cracks * 0.45) * attack * decay
			"wind_gust":
				var envelope := pow(sin(PI * clampf(t / duration, 0.0, 1.0)), 1.5)
				sample = (soft * 0.2 + rumble * 0.6 + deep * 0.9) * envelope
		samples[i] = sample
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var sample: float = samples[i]
		if looping:
			sample = samples[i + overlap]
			if i >= count - overlap:
				var head := i - (count - overlap)
				var blend := float(head) / overlap
				sample = lerpf(samples[i + overlap], samples[head], blend)
		bytes.encode_s16(i * 2, int(clampf(sample, -0.95, 0.95) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream
