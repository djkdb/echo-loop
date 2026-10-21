extends Node
## 효과음(autoload Sfx). 시작할 때 sfxr 스타일로 코드 합성해 두고 SFX 버스로 재생한다(외부 음원·라이선스 없음).
## 연출 쪽(_process, 연출 시그널)에서만 부른다. 잡음 난수는 시드 고정이고 게임플레이와 무관하다.

## 재생할 때마다(테스트·디버그용).
signal played(sound: String)

const RATE: int = 22050
const BUS: StringName = &"SFX"
const VOICES: int = 8

var streams: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20261021
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)
	streams = {
		"rewind": _make(0.5, func(t: float, k: float) -> float: return _saw(t, lerpf(900.0, 140.0, k)) * (0.6 + 0.4 * sin(t * 80.0)) * (1.0 - k * 0.6) * 0.5),
		"jump": _make(0.12, func(t: float, k: float) -> float: return _square(t, lerpf(320.0, 720.0, k)) * (1.0 - k) * 0.35),
		"land": _make(0.08, func(t: float, k: float) -> float: return _noise() * pow(1.0 - k, 3.0) * 0.5),
		"plate": _make(0.07, func(t: float, k: float) -> float: return (_square(t, 180.0) * 0.5 + _noise() * 0.3 * (1.0 - k)) * pow(1.0 - k, 2.0) * 0.45),
		"door": _make(0.16, func(t: float, k: float) -> float: return (_noise() * 0.5 + _saw(t, lerpf(90.0, 260.0, k)) * 0.5) * sin(PI * k) * 0.45),
		"lever": _make(0.09, func(t: float, k: float) -> float: return (_noise() * (1.0 if k < 0.15 or (k > 0.55 and k < 0.7) else 0.0) + _square(t, 520.0) * 0.2) * (1.0 - k) * 0.6),
		"clear": _make(0.6, func(t: float, k: float) -> float: return _square(t, [523.25, 659.25, 783.99, 1046.5][mini(int(k * 4.0), 3)]) * (1.0 - fmod(k * 4.0, 1.0) * 0.5) * (1.0 - k * 0.5) * 0.3),
		"collapse": _make(0.35, func(t: float, k: float) -> float: return _crush(_square(t, [880.0, 220.0, 660.0, 110.0, 440.0][int(k * 9.0) % 5]) * 0.6 + _noise() * 0.4) * (1.0 - k) * 0.45),
		"tick": _make(0.035, func(t: float, k: float) -> float: return sin(TAU * 1250.0 * t) * pow(1.0 - k, 4.0) * 0.6),
	}


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		push_warning("Sfx: 없는 소리 %s" % sound)
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	played.emit(sound)


## gen(t초, k = 0→1 진행률) → -1..1 샘플.
func _make(seconds: float, gen: Callable) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / RATE
		var v: float = clampf(gen.call(t, float(i) / float(n)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _square(t: float, f: float) -> float:
	return 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0


func _saw(t: float, f: float) -> float:
	return fmod(t * f, 1.0) * 2.0 - 1.0


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _crush(v: float) -> float:
	return roundf(v * 4.0) / 4.0
