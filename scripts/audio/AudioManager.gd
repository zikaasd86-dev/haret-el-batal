extends Node
## Autoload: AudioManager
## مولّد صوتيات Chiptune ومؤثرات صوتية أصلية 100% بالكود (بدون أي ملفات خارجية)
## يولّد عينات PCM 16-bit في الذاكرة عند التشغيل لضمان أصالة كاملة وأداء ممتاز على الموبايل

const MIX_RATE := 22050

var _sfx_streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	_build_sfx_bank()
	_setup_players()
	_start_bgm()
	GameState.music_changed.connect(_on_music_changed)
	_on_music_changed(GameState.music_enabled)


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
func _start_bgm() -> void:
	# ترددات مقام الحجاز على درجة الري (D4 .. D5)
	const N_REST := 0.0
	const D4  := 293.66
	const Eb4 := 311.13
	const Fs4 := 369.99
	const G4  := 392.00
	const A4  := 440.00
	const Bb4 := 466.16
	const C5  := 523.25
	const D5  := 587.33

	# لحن أصلي من 16 خطوة (إيقاع أكشن أركيد سريع)
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

	var step_dur := 0.145 # ~103 BPM إيقاع حماسى
	var step_samples := int(MIX_RATE * step_dur)
	var total_samples := melody.size() * step_samples
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	var lead_phase := 0.0
	var bass_phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026

	for s_idx in range(melody.size()):
		var lead_freq: float = melody[s_idx]
		var bass_freq: float = bass[s_idx % bass.size()]
		var has_hat := (s_idx % 2 == 1)

		for i in range(step_samples):
			var local_t := float(i) / float(step_samples)
			var sample := 0.0

			# قناة اللحن الرئيسي (Square Wave 25% duty feel)
			if lead_freq > 0.0:
				lead_phase += TAU * lead_freq / float(MIX_RATE)
				var env := clampf(1.0 - local_t * 0.65, 0.0, 1.0)
				sample += (1.0 if sin(lead_phase) > 0.25 else -1.0) * 0.22 * env

			# قناة الباص (Triangle Wave)
			bass_phase += TAU * bass_freq / float(MIX_RATE)
			var tri := (2.0 / PI) * asin(sin(bass_phase))
			sample += tri * 0.28

			# إيقاع طبلة/هاي-هات خفيف بالضوضاء
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

	_bgm_player.stream = bgm
	_bgm_player.play()
