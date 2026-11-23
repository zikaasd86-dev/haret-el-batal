extends Node
## Autoload: AudioManager
## مولّد صوتيات Chiptune ومؤثرات صوتية أصلية 100% بالكود (بدون أي ملفات خارجية)
## يولّد عينات PCM 16-bit في الذاكرة عند التشغيل لضمان أصالة كاملة وأداء ممتاز على الموبايل

const MIX_RATE := 22050

var _sfx_streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _bgm_player: AudioStreamPlayer
var _alley_bgm: AudioStreamWAV
var _boss_bgm: AudioStreamWAV
var _is_boss_music: bool = false


func _ready() -> void:
	_build_sfx_bank()
	_setup_players()
	_alley_bgm = _build_alley_bgm()
	_boss_bgm = _build_boss_bgm()
	_bgm_player.stream = _alley_bgm
	GameState.music_changed.connect(_on_music_changed)
	GameState.boss_activated.connect(_on_boss_activated)
	_on_music_changed(GameState.music_enabled)


func _on_boss_activated(active: bool) -> void:
	if _is_boss_music == active:
		return
	_is_boss_music = active
	_bgm_player.stream = _boss_bgm if active else _alley_bgm
	if GameState.music_enabled:
		_bgm_player.play()


func _on_music_changed(enabled: bool) -> void:
	if not _bgm_player:
		return
	if enabled:
		if not _bgm_player.playing:
			_bgm_player.play()
	else:
		_bgm_player.stop()


func _setup_players() -> void:
	# 6 قنوات SFX متوازية لعدم تقطع الأصوات أثناء الإطلاق السريع
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -12.0
	add_child(_bgm_player)


func play_sfx(sfx_name: String) -> void:
	if not GameState.sfx_enabled or not _sfx_streams.has(sfx_name):
		return
	var player := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	player.stream = _sfx_streams[sfx_name]
	player.play()


func _build_sfx_bank() -> void:
	# إطلاق نار البطل: موجة مربعة تهبط بسرعة
	_sfx_streams["shoot"] = _synth_sweep(0.075, 760.0, 240.0, "square", 0.35)
	# إطلاق نار الأعداء: نغمة أعمق
	_sfx_streams["enemy_shoot"] = _synth_sweep(0.09, 340.0, 150.0, "square", 0.30)
	# قفز: موجة مربعة تصعد بسرعة
	_sfx_streams["jump"] = _synth_sweep(0.11, 220.0, 580.0, "square", 0.32)
	# إصابة: ضوضاء قصيرة + نغمة حادة
	_sfx_streams["hit"] = _synth_sweep(0.09, 440.0, 110.0, "noise_mix", 0.42)
	# انفجار عدو أو زعيم: ضوضاء 8-bit متلاشية
	_sfx_streams["explode"] = _synth_sweep(0.28, 160.0, 45.0, "noise", 0.50)


## توليد مؤثر صوتي أصلي كـ AudioStreamWAV في الذاكرة
func _synth_sweep(duration: float, f_start: float, f_end: float, wave: String, volume: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)

	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f_start * 100.0 + duration * 1000.0)

	for i in range(count):
		var t := float(i) / float(count)
		var freq := lerpf(f_start, f_end, t)
		var env := (1.0 - t) * (1.0 - t) # تلاشي ناعم
		phase += TAU * freq / float(MIX_RATE)

		var sample := 0.0
		match wave:
			"square":
				sample = 1.0 if sin(phase) >= 0.0 else -1.0
			"noise":
				sample = rng.randf_range(-1.0, 1.0)
			"noise_mix":
				var sq := 1.0 if sin(phase) >= 0.0 else -1.0
				sample = sq * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45

		var val := int(clampf(sample * env * volume, -1.0, 1.0) * 32767.0)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


## توليد لحن Chiptune أصلي 100% بطابع مصري (مقام حجاز: D Eb F# G A Bb C D)
func _build_alley_bgm() -> AudioStreamWAV:
	const N_REST := 0.0
	const D4  := 293.66
	const Eb4 := 311.13
	const Fs4 := 369.99
	const G4  := 392.00
	const A4  := 440.00
	const Bb4 := 466.16
	const C5  := 523.25
	const D5  := 587.33

	var melody := [
		D4, Fs4, G4, A4,  Bb4, A4, G4, Fs4,
		G4, A4, Bb4, D5,  C5, Bb4, A4, N_REST,
		D5, Bb4, A4, G4,  A4, G4, Fs4, Eb4,
		D4, Fs4, A4, G4,  Fs4, Eb4, D4, N_REST,
	]
	var bass := [
		D4 * 0.5, D4 * 0.5, A4 * 0.5, D4 * 0.5,
		G4 * 0.5, G4 * 0.5, D4 * 0.5, A4 * 0.5,
	]
	return _synth_track(melody, bass, 0.145, 2026)


## لحن قتال الزعيم (إيقاع أسرع وأكثر توتراً وحماساً عند دخول ساحة الزعيم)
func _build_boss_bgm() -> AudioStreamWAV:
	const N_REST := 0.0
	const A4  := 440.00
	const Bb4 := 466.16
	const Cs5 := 554.37
	const D5  := 587.33
	const E5  := 659.25
	const F5  := 698.46
	const G5  := 783.99

	var melody := [
		A4, A4, Bb4, A4,  Cs5, D5, Cs5, Bb4,
		A4, E5, F5, E5,   D5, Cs5, Bb4, A4,
		D5, D5, E5, F5,   G5, F5, E5, D5,
		Cs5, Bb4, A4, N_REST, A4, Cs5, E5, N_REST,
	]
	var bass := [
		A4 * 0.25, A4 * 0.5, A4 * 0.25, Bb4 * 0.25,
		D5 * 0.25, D5 * 0.5, Cs5 * 0.25, A4 * 0.25,
	]
	return _synth_track(melody, bass, 0.105, 9090)


func _synth_track(melody: Array, bass: Array, step_dur: float, seed_val: int) -> AudioStreamWAV:
	var step_samples := int(MIX_RATE * step_dur)
	var total_samples := melody.size() * step_samples
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	var lead_phase := 0.0
	var bass_phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	for s_idx in range(melody.size()):
		var lead_freq: float = melody[s_idx]
		var bass_freq: float = bass[s_idx % bass.size()]
		var has_hat := (s_idx % 2 == 1)

		for i in range(step_samples):
			var local_t := float(i) / float(step_samples)
			var sample := 0.0

			if lead_freq > 0.0:
				lead_phase += TAU * lead_freq / float(MIX_RATE)
				var env := clampf(1.0 - local_t * 0.65, 0.0, 1.0)
				sample += (1.0 if sin(lead_phase) > 0.25 else -1.0) * 0.22 * env

			bass_phase += TAU * bass_freq / float(MIX_RATE)
			var tri := (2.0 / PI) * asin(sin(bass_phase))
			sample += tri * 0.28

			if has_hat and local_t < 0.22:
				sample += rng.randf_range(-1.0, 1.0) * 0.12 * (1.0 - local_t / 0.22)

			var g_idx := s_idx * step_samples + i
			var val := int(clampf(sample, -1.0, 1.0) * 32767.0)
			data[g_idx * 2] = val & 0xFF
			data[g_idx * 2 + 1] = (val >> 8) & 0xFF

	var bgm := AudioStreamWAV.new()
	bgm.format = AudioStreamWAV.FORMAT_16_BITS
	bgm.mix_rate = MIX_RATE
	bgm.stereo = false
	bgm.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bgm.loop_begin = 0
	bgm.loop_end = total_samples
	bgm.data = data
	return bgm
