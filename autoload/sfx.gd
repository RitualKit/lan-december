extends Node
## Tiny chiptune synthesizer: every sound effect is generated at startup, no audio files needed.
## Drop an .ogg/.wav with the same name into res://assets/sfx/ to override one.
## A few sounds come from the Ninja Adventure pack (FILES).

const RATE := 22050
const VOICES := 16

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

const FILES := {
	"powerup": "res://assets/ninja_adventure/sounds/power-up.ogg",
	"magic": "res://assets/ninja_adventure/sounds/magic-1.ogg",
	"throw": "res://assets/ninja_adventure/sounds/sword.ogg",
	"ko": "res://assets/ninja_adventure/sounds/kill.ogg",
}

# name -> list of tones: [wave, freq_start, freq_end, duration, volume, delay, lowpass]
const SOUNDS := {
	"blip": [["square", 660, 660, 0.09, 0.35, 0.0, 1.0]],
	"go": [["square", 880, 880, 0.12, 0.35, 0.0, 1.0], ["square", 1320, 1320, 0.3, 0.35, 0.1, 1.0]],
	"join": [["square", 520, 1040, 0.12, 0.3, 0.0, 1.0], ["square", 1040, 1040, 0.08, 0.25, 0.12, 1.0]],
	"leave": [["square", 700, 350, 0.15, 0.3, 0.0, 1.0]],
	"dash": [["noise", 0, 0, 0.14, 0.35, 0.0, 0.25]],
	"hit": [["square", 320, 110, 0.13, 0.4, 0.0, 1.0], ["noise", 0, 0, 0.08, 0.35, 0.0, 0.5]],
	"coin": [["square", 990, 990, 0.06, 0.3, 0.0, 1.0], ["square", 1480, 1480, 0.14, 0.3, 0.06, 1.0]],
	"gold": [["square", 990, 990, 0.06, 0.3, 0.0, 1.0], ["square", 1320, 1320, 0.06, 0.3, 0.06, 1.0], ["square", 1980, 1980, 0.2, 0.3, 0.12, 1.0]],
	"splash": [["noise", 0, 0, 0.5, 0.5, 0.0, 0.12], ["sine", 300, 90, 0.25, 0.3, 0.0, 1.0]],
	"boom": [["noise", 0, 0, 0.8, 0.7, 0.0, 0.08], ["sine", 110, 35, 0.6, 0.6, 0.0, 1.0]],
	"tick": [["square", 1250, 1250, 0.03, 0.2, 0.0, 1.0]],
	"crack": [["noise", 0, 0, 0.12, 0.3, 0.0, 0.6]],
	"paint": [["triangle", 420, 640, 0.05, 0.12, 0.0, 1.0]],
	"fault": [["square", 180, 160, 0.35, 0.35, 0.0, 0.5]],
	"point": [["triangle", 880, 1320, 0.12, 0.35, 0.0, 1.0]],
	"jump": [["square", 300, 700, 0.12, 0.25, 0.0, 0.6]],
	"whistle": [["sine", 1800, 2400, 0.25, 0.35, 0.0, 1.0]],
	"win": [
		["square", 523, 523, 0.1, 0.3, 0.0, 1.0], ["square", 659, 659, 0.1, 0.3, 0.1, 1.0],
		["square", 784, 784, 0.1, 0.3, 0.2, 1.0], ["square", 1046, 1046, 0.35, 0.3, 0.3, 1.0],
	],
	"fanfare": [
		["square", 523, 523, 0.12, 0.3, 0.0, 1.0], ["square", 523, 523, 0.12, 0.3, 0.15, 1.0],
		["square", 523, 523, 0.12, 0.3, 0.3, 1.0], ["square", 784, 784, 0.5, 0.3, 0.45, 1.0],
		["triangle", 262, 262, 0.9, 0.35, 0.0, 1.0], ["triangle", 392, 392, 0.5, 0.35, 0.45, 1.0],
	],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for sound in SOUNDS:
		get_stream(sound)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func play_varied(sound: String, spread := 0.08, volume_db := 0.0) -> void:
	play(sound, randf_range(1.0 - spread, 1.0 + spread), volume_db)


func get_stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var stream: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := "res://assets/sfx/%s.%s" % [sound, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null and FILES.has(sound):
		stream = load(FILES[sound])
	if stream == null and SOUNDS.has(sound):
		stream = synth(SOUNDS[sound])
	if stream == null:
		push_warning("Sfx: unknown sound '%s'" % sound)
	_streams[sound] = stream
	return stream


static func synth(tones: Array) -> AudioStreamWAV:
	var length := 0.0
	for t in tones:
		length = maxf(length, t[3] + t[5])
	var n := int(length * RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for t in tones:
		var wave: String = t[0]
		var dur: float = t[3]
		var vol: float = t[4]
		var start := int(t[5] * RATE)
		var lp: float = t[6]
		var phase := 0.0
		var filtered := 0.0
		var count := int(dur * RATE)
		for i in count:
			var k := float(i) / count
			var freq := lerpf(t[1], t[2], k)
			phase = fmod(phase + freq / RATE, 1.0)
			var s := 0.0
			match wave:
				"square": s = 1.0 if phase < 0.5 else -1.0
				"triangle": s = 4.0 * absf(phase - 0.5) - 1.0
				"sine": s = sin(phase * TAU)
				"noise": s = rng.randf_range(-1.0, 1.0)
			filtered += (s - filtered) * lp
			# Short attack, linear decay.
			var env := minf(1.0, i / (RATE * 0.004)) * (1.0 - k)
			var idx := start + i
			if idx < n:
				buf[idx] += filtered * vol * env
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
