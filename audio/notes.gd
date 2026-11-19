# 8 つの音と、数え・外れ・終わりの音の再生(仕様書 §9.9・FR-3・FR-21・FR-23。autoload Notes)。
# キーごとに 1 つのプレイヤーを持ち、同じキーが続いたら頭から鳴らし直す。薄い音は −12 dB。unlock() の前は鳴らさない。
# 音量の設定はマスターのバスに掛ける(伴奏・お手本・押した音の全部に効く)。0 はバスを消音にし、伴奏は止めない(曲の位置を進め続ける)。
extends Node

const B := preload("res://core/balance.gd")
const DIR := "res://assets/audio/"
const SFX: Array = ["click", "miss", "over"]

var volume := B.DEFAULT_VOLUME  # 0〜100
var unlocked := false
var played := 0  # 再生を始めた回数(テストが読む)
var last_key := -1  # 最後に鳴らしたキー(テストが読む)

var _keys: Array[AudioStreamPlayer] = []
var _sfx := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in B.KEYS_N:
		_keys.append(_player(DIR + "note_%d.wav" % k))
	for n: String in SFX:
		_sfx[n] = _player(DIR + n + ".wav")
	set_volume(volume)


func _player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		p.stream = load(path) as AudioStream  # 読めなければ音なしで続ける
	add_child(p)
	return p


func unlock() -> void:
	unlocked = true


# 25〜100 は 2 乗で dB に直す(100 → 0 dB、75 → −5 dB、50 → −12 dB、25 → −24 dB)。0 は消音。
func set_volume(percent: int) -> void:
	volume = clampi(percent, 0, 100)
	AudioServer.set_bus_volume_db(0, linear_to_db(pow(volume / 100.0, 2.0)) if volume > 0 else B.LAYER_OFF_DB)
	AudioServer.set_bus_mute(0, volume == 0)


# キー k(0〜7)の音。dim なら薄い音。
func play_key(k: int, dim: bool = false) -> void:
	if not unlocked or k < 0 or k >= _keys.size():
		return
	var p := _keys[k]
	p.volume_db = B.DIM_DB if dim else 0.0
	p.play()
	played += 1
	last_key = k


func play(sound_name: String) -> void:
	if not unlocked or not _sfx.has(sound_name):
		return
	_sfx[sound_name].play()
	played += 1
