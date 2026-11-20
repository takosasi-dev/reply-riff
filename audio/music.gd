# 伴奏の再生と曲の位置(仕様書 §9.9・D-10・D-11。autoload Music)。4 層を 1 つの AudioStreamSynchronized に入れて 9.6 秒をくり返し、層の音量で足す。
# 曲の位置(秒)= くり返しの回数 × 9.6 + 再生の位置 + 最後のミックスからの時間 − 出力の遅れ。回数は生の再生の位置が大きく戻った時にだけ足す。
# 伴奏のプレイヤーだけ Stream で鳴らす(Web の既定の Sample では、途中の音量の変更と再生の位置が使えない)。鍵盤の音は既定のまま。
extends Node

const B := preload("res://core/balance.gd")
const DIR := "res://assets/audio/"

var layers := 0  # 鳴らしている層の数(テストが読む)
var loops := 0
var player: AudioStreamPlayer
var _sync: AudioStreamSynchronized
var probe_ctx := false  # ?debug=1 の Web だけ: 曲の位置を読んだ時に、ブラウザの AudioContext の時刻も読む(R-4 の目安)
var last_pair: Array = []  # [曲の位置(秒), AudioContext の時刻(秒)]
var _last_raw := 0.0
var _raw_moved_at := 0  # 生の位置が最後に動いた時刻(ms)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = B.MAX_LAYERS
	for k in B.MAX_LAYERS:
		var path := DIR + "layer_%d.wav" % (k + 1)
		var s: AudioStreamWAV = load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
		if s != null:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(round(B.LOOP_SEC * s.mix_rate))
			_sync.set_sync_stream(k, s)
	player = AudioStreamPlayer.new()
	player.stream = _sync
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	set_layers(0)


# 層の数(0〜4)。層が無効なら無音、有効なら 0 dB。
func set_layers(n: int) -> void:
	layers = clampi(n, 0, B.MAX_LAYERS)
	for k in B.MAX_LAYERS:
		_sync.set_sync_stream_volume(k, 0.0 if k < layers else B.LAYER_OFF_DB)


# 曲の tick の位置から鳴らす(始める時と、一時停止から戻る時)。
@warning_ignore("integer_division")
func start_at(tick: int) -> void:
	var loop_ticks := int(round(B.LOOP_SEC * B.TICK_HZ))
	loops = tick / loop_ticks
	_last_raw = float(tick % loop_ticks) / B.TICK_HZ
	_raw_moved_at = Time.get_ticks_msec()
	player.stream_paused = false
	player.play(_last_raw)


func pause() -> void:
	player.stream_paused = true


func stop() -> void:
	player.stop()
	set_layers(0)


func is_running() -> bool:
	return player.playing and not player.stream_paused


# 曲の位置(秒)。毎フレーム 1 回呼ぶ(くり返しの回数を数えるため)。
func song_sec() -> float:
	var raw := player.get_playback_position()
	if raw < _last_raw - B.LOOP_SEC / 2:
		loops += 1
	if raw != _last_raw:
		_raw_moved_at = Time.get_ticks_msec()
	_last_raw = raw
	var sec := loops * B.LOOP_SEC + raw + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	if probe_ctx:
		var ctx: Variant = JavaScriptBridge.eval("window.__rrCtx ? window.__rrCtx.currentTime : -1", true)
		last_pair = [sec, float(ctx) if (ctx is float or ctx is int) else -1.0]
	return sec


# 鳴らしているのに、生の位置が STALL_MS 動いていない(音の出力が止まっている。E-11 の保険)。
func stalled() -> bool:
	return is_running() and Time.get_ticks_msec() - _raw_moved_at > B.STALL_MS
