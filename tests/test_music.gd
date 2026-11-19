# 曲の位置の時計のテスト(§9.9・D-11)。ヘッドレスの音の出力(Dummy)は実時間で進むので、数百 ms 待って位置を読む。
# 前へ進む・くり返しをまたぐ・tick の位置へ移した直後・一時停止で止まる・層の音量、を見る。
extends "res://tests/suite.gd"


func test_music_clock_moves_and_wraps() -> bool:
	Music.start_at(0)
	OS.delay_msec(400)
	var a: float = Music.song_sec()
	ok(a > 0.2 and a < 2.0, "頭から 0.4 秒(%.3f)" % a)
	Music.start_at(1100)  # 9.1667 秒。くり返しの 0.43 秒前
	var b: float = Music.song_sec()
	ok(absf(b - 1100.0 / B.TICK_HZ) < 0.3, "移した直後の位置(%.3f)" % b)
	OS.delay_msec(900)
	var c: float = Music.song_sec()
	eq(Music.loops, 1, "くり返しを 1 回またいだ")
	ok(c > 9.7 and c < 12.0, "くり返しの後も続きの位置(%.3f)" % c)
	Music.start_at(3000)
	var d: float = Music.song_sec()
	eq(Music.loops, 2, "3000 tick は 2 回目のくり返しの中")
	ok(absf(d - 25.0) < 0.3, "移した直後(%.3f)" % d)
	OS.delay_msec(100)
	ok(Music.song_sec() >= d, "戻らない")
	Music.stop()
	return true


func test_music_pause_and_layers() -> bool:
	Music.start_at(600)
	OS.delay_msec(150)
	Music.pause()
	ok(not Music.is_running(), "一時停止")
	# 一時停止の間は ui が曲の位置を読まない。再生の位置そのものが止まっていればよい(最後のミックスからの時間は CI の負荷で揺れる)
	OS.delay_msec(100)  # 止めるのは次のミックスから
	var a: float = Music.player.get_playback_position()
	OS.delay_msec(300)
	var b: float = Music.player.get_playback_position()
	ok(absf(b - a) < 0.001, "止まっている間は再生の位置が進まない(%.3f → %.3f)" % [a, b])
	Music.set_layers(2)
	eq([Music._sync.get_sync_stream_volume(0), Music._sync.get_sync_stream_volume(1), Music._sync.get_sync_stream_volume(3)], [0.0, 0.0, B.LAYER_OFF_DB], "層 2 はドラムとベース")
	Music.set_layers(9)
	eq(Music.layers, 4, "最大 4")
	Music.stop()
	eq(Music.layers, 0, "止めると層 0")
	ok(Music._sync.get_sync_stream(3) != null, "4 層とも読めた")
	eq(Music.player.playback_type, AudioServer.PLAYBACK_TYPE_STREAM, "伴奏は Stream で鳴らす")
	return true


# フレームの間が STALL_MS を超えても(Web の最初の描画など)、次のフレームで曲の位置の時計へ戻る。
func test_stall_guard_recovers() -> bool:
	Music.start_at(0)
	OS.delay_msec(B.STALL_MS + 150)
	ok(Music.stalled(), "読まない間は止まって見える")
	Music.song_sec()
	ok(not Music.stalled(), "読めば止まっていない")
	var play := Play.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	play.start(0, 1)  # 曲を頭から鳴らす
	OS.delay_msec(B.STALL_MS + 150)
	for k in 3:
		play._process(1.0 / 60.0)
		OS.delay_msec(20)
	var want := Music.song_sec() * B.TICK_HZ
	ok(absf(play._free - want) < 12.0, "目標の tick が曲の位置に戻る(%.1f と %.1f)" % [play._free, want])
	ok(play.sim.tick >= 48, "sim も 1 フレーム 16 tick ずつ追う(%d)" % play.sim.tick)
	play.queue_free()
	Music.stop()
	return true


const Play := preload("res://ui/play.gd")
