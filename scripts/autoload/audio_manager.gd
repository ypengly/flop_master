extends Node
## Fully procedural audio: no asset files needed. Every sound effect and the comedic
## music loop are synthesized at startup into AudioStreamWAV resources.
## Swap in real files by assigning to `sounds[name]`.

const RATE := 22050
const POOL_SIZE := 10

var sounds: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _music: AudioStreamPlayer
var _last_play: Dictionary = {}


func _ready() -> void:
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_build_sounds()
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(SaveData.get_setting("master", 0.8)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(SaveData.get_setting("sfx", 1.0)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(SaveData.get_setting("music", 0.5)))))


## Play a named effect. Pitch is randomized slightly for comedic variety.
func play(sound_name: String, volume := 1.0, pitch := 1.0, rand_pitch := 0.08) -> void:
	if not sounds.has(sound_name):
		return
	var now := Time.get_ticks_msec()
	if _last_play.has(sound_name) and now - int(_last_play[sound_name]) < 45:
		return # avoid stacking identical sounds in the same few frames
	_last_play[sound_name] = now
	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = sounds[sound_name]
	p.volume_db = linear_to_db(clampf(volume, 0.001, 2.0))
	p.pitch_scale = pitch * (1.0 + randf_range(-rand_pitch, rand_pitch))
	p.play()


func play_impact(speed: float, material := "stone") -> void:
	var v := clampf(speed / 18.0, 0.15, 1.0)
	match material:
		"rubber": play("boing", v, 0.8 + randf() * 0.5)
		"soft": play("squish", v)
		"metal": play("clang", v, 0.9 + randf() * 0.3)
		"ice": play("thud", v * 0.6, 1.5)
		_: play("thud", v, 0.8 + randf() * 0.4)
	if speed > 14.0 and randf() < 0.5:
		play("grunt", 0.8, 0.8 + randf() * 0.6)


func play_music() -> void:
	if sounds.has("music") and not _music.playing:
		_music.stream = sounds["music"]
		_music.play()


func stop_music() -> void:
	_music.stop()


# ---------------------------------------------------------------- synthesis

func _make(duration: float, fn: Callable, loop := false) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := clampf(float(fn.call(t, duration)), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


func _env(t: float, dur: float, attack := 0.005) -> float:
	var a := minf(t / attack, 1.0)
	var r := clampf((dur - t) / dur, 0.0, 1.0)
	return a * r * r


func _build_sounds() -> void:
	sounds["thud"] = _make(0.22, func(t, d): return (sin(TAU * (90.0 - 50.0 * t / d) * t) * 0.9 + (randf() - 0.5) * 0.35 * exp(-t * 40.0)) * _env(t, d))
	sounds["boing"] = _make(0.45, func(t, d): return sin(TAU * (260.0 + 160.0 * sin(t * 28.0)) * t) * 0.6 * _env(t, d))
	sounds["squish"] = _make(0.18, func(t, d): return ((randf() - 0.5) * 0.5 + sin(TAU * 140.0 * t) * 0.4) * _env(t, d))
	sounds["clang"] = _make(0.5, func(t, d): return (sin(TAU * 520.0 * t) + sin(TAU * 837.0 * t) * 0.6 + sin(TAU * 1210.0 * t) * 0.3) * 0.35 * exp(-t * 7.0))
	sounds["grunt"] = _make(0.28, func(t, d): return (signf(sin(TAU * (110.0 - 40.0 * t / d) * t)) * 0.28 + (randf() - 0.5) * 0.1) * _env(t, d, 0.02))
	sounds["whoosh"] = _make(0.35, func(t, d): return (randf() - 0.5) * 0.5 * sin(PI * t / d))
	sounds["jump"] = _make(0.2, func(t, d): return sin(TAU * (300.0 + 700.0 * t / d) * t) * 0.5 * _env(t, d))
	sounds["grab"] = _make(0.1, func(t, d): return sin(TAU * 180.0 * t) * 0.5 * _env(t, d))
	sounds["pickup"] = _make(0.3, func(t, d): return sin(TAU * (880.0 if t < 0.1 else 1320.0) * t) * 0.45 * _env(t, d))
	sounds["checkpoint"] = _make(0.5, func(t, d): return sin(TAU * [523.0, 659.0, 784.0][mini(int(t / 0.16), 2)] * t) * 0.4 * _env(t, d))
	sounds["win"] = _make(1.0, func(t, d): return sin(TAU * [523.0, 659.0, 784.0, 1046.0][mini(int(t / 0.25), 3)] * t) * 0.45 * _env(t, d, 0.01))
	sounds["fail"] = _make(0.8, func(t, d): return sin(TAU * (400.0 - 300.0 * t / d) * t) * 0.5 * _env(t, d))
	sounds["click"] = _make(0.06, func(t, d): return sin(TAU * 700.0 * t) * 0.4 * _env(t, d))
	sounds["honk"] = _make(0.35, func(t, d): return (signf(sin(TAU * 220.0 * t)) * 0.2 + signf(sin(TAU * 277.0 * t)) * 0.2) * _env(t, d, 0.01))
	sounds["music"] = _build_music()


const MUSIC_BPM := 130.0
const MUSIC_BASS := [130.8, 130.8, 196.0, 196.0, 174.6, 174.6, 196.0, 164.8]
const MUSIC_LEAD := [523.3, 0.0, 659.3, 784.0, 659.3, 0.0, 587.3, 0.0, 523.3, 659.3, 784.0, 0.0, 880.0, 784.0, 659.3, 0.0]


func _build_music() -> AudioStreamWAV:
	# 16-beat bouncy "tuba and plink" loop, C major pentatonic.
	var total := (60.0 / MUSIC_BPM) * 16.0
	return _make(total, Callable(self, "_music_sample"), true)


func _music_sample(t: float, _d: float) -> float:
	var beat := 60.0 / MUSIC_BPM
	var b := int(t / beat) % 16
	var bt := fmod(t, beat) / beat
	var bf: float = MUSIC_BASS[(b / 2) % 8]
	var bass_s := 0.0
	if b % 2 == 0 or bt < 0.5:
		bass_s = signf(sin(TAU * bf * t)) * 0.12 * (1.0 - bt * 0.6)
	var lf: float = MUSIC_LEAD[b]
	var lead_s := 0.0
	if lf > 0.0:
		lead_s = sin(TAU * lf * t) * 0.12 * exp(-bt * 5.0)
	var hat := (randf() - 0.5) * 0.05 * exp(-fmod(t, beat * 0.5) * 40.0)
	return bass_s + lead_s + hat
