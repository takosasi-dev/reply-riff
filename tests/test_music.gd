# 曲の位置の時計のテスト(§9.9・D-11)。ヘッドレスの音の出力(Dummy)は実時間で進むので、数百 ms 待って位置を読む。
# 前へ進む・くり返しをまたぐ・tick の位置へ移した直後・一時停止で止まる・層の音量、を見る。
extends "res://tests/suite.gd"


func test_music_clock_moves_and_wraps() -> bool:
	Music.start_at(0)
	OS.delay_msec(400)
	var a: float = Music.song_sec()
	ok(a > 0.2 and a < 0.8, "頭から 0.4 秒(%.3f)" % a)
	Music.start_at(1100)  # 9.1667 秒。くり返しの 0.43 秒前
	var b: float = Music.song_sec()
	ok(absf(b - 1100.0 / B.TICK_HZ) < 0.15, "移した直後の位置(%.3f)" % b)
	OS.delay_msec(900)
	var c: float = Music.song_sec()
	eq(Music.loops, 1, "くり返しを 1 回またいだ")
	ok(c > 9.8 and c < 10.6, "くり返しの後も続きの位置(%.3f)" % c)
	Music.start_at(3000)
	var d: float = Music.song_sec()
	eq(Music.loops, 2, "3000 tick は 2 回目のくり返しの中")
	ok(absf(d - 25.0) < 0.15, "移した直後(%.3f)" % d)
	OS.delay_msec(100)
	ok(Music.song_sec() >= d, "戻らない")
	Music.stop()
	return true


func test_music_pause_and_layers() -> bool:
	Music.start_at(600)
	OS.delay_msec(150)
	Music.pause()
	ok(not Music.is_running(), "一時停止")
	var a: float = Music.song_sec()
	OS.delay_msec(300)
	ok(absf(Music.song_sec() - a) < 0.06, "止まっている間は進まない")
	Music.set_layers(2)
	eq([Music._sync.get_sync_stream_volume(0), Music._sync.get_sync_stream_volume(1), Music._sync.get_sync_stream_volume(3)], [0.0, 0.0, B.LAYER_OFF_DB], "層 2 はドラムとベース")
	Music.set_layers(9)
	eq(Music.layers, 4, "最大 4")
	Music.stop()
	eq(Music.layers, 0, "止めると層 0")
	ok(Music._sync.get_sync_stream(3) != null, "4 層とも読めた")
	eq(Music.player.playback_type, AudioServer.PLAYBACK_TYPE_STREAM, "伴奏は Stream で鳴らす")
	return true
