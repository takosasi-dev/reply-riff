# 音の同期の API(仕様書 §8.1・前提 4)が 4.7.2 にあるかと、ヘッドレスで再生の位置が進むかを確かめて印字する。
# 実行: python tools/gd.py run res://tools/audio_probe.gd
extends SceneTree


func _initialize() -> void:
	for c: String in ["AudioStreamSynchronized", "AudioStreamPlaybackSynchronized", "AudioStreamWAV"]:
		print(c, " ", ClassDB.class_exists(c))
	for pair: Array in [["AudioStreamSynchronized", "set_sync_stream"], ["AudioStreamSynchronized", "set_sync_stream_volume"],
			["AudioStreamSynchronized", "set_stream_count"], ["AudioServer", "get_time_since_last_mix"],
			["AudioServer", "get_output_latency"], ["AudioServer", "get_time_to_next_mix"], ["AudioStreamPlayer", "get_playback_position"],
			["AudioStreamPlayer", "seek"], ["AudioServer", "set_bus_volume_db"], ["AudioServer", "set_bus_mute"]]:
		print(pair[0], ".", pair[1], " ", ClassDB.class_has_method(pair[0], pair[1]))
	print("AudioStreamSynchronized の項目: ", ClassDB.class_get_property_list("AudioStreamSynchronized", true).map(func(p: Dictionary) -> String: return p["name"]))
	print("AudioStreamWAV の項目: ", ClassDB.class_get_property_list("AudioStreamWAV", true).map(func(p: Dictionary) -> String: return p["name"]))
	print("audio driver: ", AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?", " mix_rate ", AudioServer.get_mix_rate())
	print("default_playback_type.web: ", ProjectSettings.get_setting("audio/general/default_playback_type.web", "?"))
	_run.call_deferred()


func _run() -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2)  # 1 秒の無音
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 22050
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = 2
	sync.set_sync_stream(0, wav)
	sync.set_sync_stream(1, wav)
	var p := AudioStreamPlayer.new()
	p.stream = sync
	root.add_child(p)
	p.play()
	var t0 := Time.get_ticks_msec()
	var last := -1.0
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
		var pos := p.get_playback_position()
		if absf(pos - last) > 0.2 or pos < last:
			print("%5d ms: pos %.3f since_mix %.4f latency %.4f playing %s" % [Time.get_ticks_msec() - t0, pos, AudioServer.get_time_since_last_mix(), AudioServer.get_output_latency(), p.playing])
			last = pos
	p.play(0.5)
	await process_frame
	await process_frame
	print("play(0.5) の後: ", p.get_playback_position())
	quit(0)
