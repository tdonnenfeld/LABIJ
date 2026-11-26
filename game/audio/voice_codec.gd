extends RefCounted

const RATE := 16000
const FRAME := 320
const BYTES := FRAME * 2
const GATE_DB := -48.0
const SHOUT_RADIUS := 12.0

static func encode(frames: PackedVector2Array) -> PackedByteArray:
	var data := PackedByteArray()
	if frames.is_empty():
		return data
	data.resize(BYTES)
	for i in range(FRAME):
		var first := floori(float(i) * frames.size() / FRAME)
		var last := mini(frames.size(), maxi(first + 1, floori(float(i + 1) * frames.size() / FRAME)))
		var value := 0.0
		for j in range(first, last):
			value += (frames[j].x + frames[j].y) * 0.5
		value /= last - first
		data.encode_s16(i * 2, roundi(clampf(value, -1.0, 1.0) * 32767.0))
	return data

static func radius(data: PackedByteArray) -> float:
	if data.size() != BYTES:
		return 0.0
	var energy := 0.0
	for i in range(FRAME):
		var value := float(data.decode_s16(i * 2)) / 32768.0
		energy += value * value
	var db := linear_to_db(maxf(0.000001, sqrt(energy / FRAME)))
	if db < GATE_DB:
		return 0.0
	return lerpf(2.0, 18.0, clampf((db - GATE_DB) / 36.0, 0.0, 1.0))

static func decode(data: PackedByteArray) -> PackedVector2Array:
	var frames := PackedVector2Array()
	if data.size() != BYTES:
		return frames
	frames.resize(FRAME)
	for i in range(FRAME):
		var value := float(data.decode_s16(i * 2)) / 32768.0
		frames[i] = Vector2(value, value)
	return frames
