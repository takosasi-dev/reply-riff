# 画面の流れのテスト(AC-18〜AC-20・FR-3・FR-17・FR-22〜FR-26・E-1・E-8・NFR-2)。main.tscn を木に置き、キーのイベントを直接渡す。
# フレームは _process を呼んで進める。プレイはフレームの時間で進める(曲の位置の時計は test_music で別に見る)。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Play := preload("res://ui/play.gd")


static func kev(pk: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = pressed
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	e.echo = echo
	return e


func _main() -> Node:
	var p := ProjectSettings.globalize_path(Store.PATH)
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(p)
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()
	Music.stop()


static func press(m: Node, pk: int) -> void:
	m._input(kev(pk))


static func frames(m: Node, n: int, dt: float = 1.0 / 60.0) -> void:
	for k in n:
		if m.play != null:
			m.play._process(dt)
		if m.current != null and m.current.has_method("_process") and m.current != m.play:
			m.current._process(dt)


# S0 → S1 → 今日の曲(フレームの時間で進める)。
func _to_play(m: Node, down: int = 0) -> void:
	press(m, KEY_X)
	for k in down:
		press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	m.play.frame_clock = true


func _finish(m: Node) -> void:
	while not m.play.sim.is_over():
		m.play.sim.step()
	m.play.finished.emit(m.play.sim.result())  # 終わった後の 600 ms を待たない


func test_ac18_flow_keyboard_only() -> bool:
	var m := _main()
	eq(m.screen, "gate", "S0 から始まる")
	press(m, KEY_A)
	eq(m.screen, "title", "どれかのキーで S1")
	ok(m.play == null, "S0 のキーはゲームの操作に数えない")
	ok(Notes.unlocked, "S0 の入力で音を出せるようにする(FR-23)")
	press(m, KEY_ENTER)
	eq(m.screen, "play", "Enter で今日の曲")
	eq(int(m.run["mode"]), 0, "今日の曲")
	m.play.frame_clock = true
	frames(m, 60)
	ok(m.play.sim.tick >= 118 and m.play.sim.tick <= 122, "1 秒で 120 tick 進む(%d)" % m.play.sim.tick)
	_finish(m)
	eq(m.screen, "result", "曲が終わると S3")
	var seed_before: int = m.run["seed"]
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_ENTER)
	eq(m.screen, "play", "もう1回(Enter)")
	eq(int(m.run["seed"]), seed_before, "今日の曲は同じ種(FR-17)")
	_done(m)
	return true


func test_result_retry_lock_and_save() -> bool:
	var m := _main()
	_to_play(m, 1)
	eq(int(m.run["mode"]), 1, "練習")
	var seed1: int = m.run["seed"]
	_finish(m)
	press(m, KEY_R)
	eq(m.screen, "result", "300 ms の前は押せない")
	ok(m.current.share.begins_with("ReplyRiff "), "共有する文字")
	ok(m.store.practice_best() != null, "練習の最高を保存")
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_R)
	eq(m.screen, "play", "R でもう1回")
	ok(int(m.run["seed"]) != seed1, "練習のもう1回は種を引き直す")
	_done(m)
	return true


func test_fr3_key_sounds_same_frame() -> bool:
	var m := _main()
	_to_play(m)
	var before: int = Notes.played
	m._input(kev(KEY_J))
	eq(Notes.played, before + 1, "押したイベントの中で鳴らす(sim を待たない)")
	eq(Notes.last_key, 4, "J はラ(4)")
	eq(m.play.key_lat_us.size(), 1, "押してから鳴らすまでを測る(NFR-2)")
	ok(int(m.play.key_lat_us[0]) < 16700, "1 フレーム以内(%d usec)" % int(m.play.key_lat_us[0]))
	frames(m, 1)
	eq(m.play.sim.presses[0], [], "数えの間の押すは判定に使わない(E-2)")
	_done(m)
	return true


func test_ac3_keys_and_g_h() -> bool:
	var m := _main()
	_to_play(m)
	var want := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON]
	for k in 8:
		m._input(kev(want[k]))
		eq(Notes.last_key, k, "キー %s は %d" % [OS.get_keycode_string(want[k]), k])
		m._input(kev(want[k], false))
	var before: int = Notes.played
	m._input(kev(KEY_G))
	m._input(kev(KEY_H))
	m._input(kev(KEY_SPACE))
	eq(Notes.played, before, "G・H・Space は何もしない")
	_done(m)
	return true


func test_fr24_echo_and_modifiers() -> bool:
	var m := _main()
	_to_play(m)
	var before: int = Notes.played
	m._input(kev(KEY_F, true, true))
	var e := kev(KEY_F)
	e.ctrl_pressed = true
	m._input(e)
	var e2 := kev(KEY_D)
	e2.alt_pressed = true
	m._input(e2)
	eq(Notes.played, before, "押しっぱなしと Ctrl・Alt 付きは数えない")
	eq(m.play.sim._queue, [], "sim にも渡さない")
	_done(m)
	return true


func test_ac19_pause_freezes_and_rewinds() -> bool:
	var m := _main()
	_to_play(m)
	frames(m, 60 * 7)  # 回 1 の判定(796)を過ぎ、回 2 のお手本の途中まで
	var t: int = m.play.sim.tick
	ok(t > 700, "回 2 まで進んだ(%d)" % t)
	press(m, KEY_ESCAPE)
	ok(m.pause_view != null, "Esc で一時停止")
	frames(m, 120)
	eq(m.play.sim.tick, t, "一時停止の間は sim が止まる")
	ok(not Music.is_running(), "曲も止まる")
	press(m, KEY_ESCAPE)
	ok(m.pause_view == null, "Esc で続ける")
	eq(m.play.sim.tick, TL.call_start(m.play.sim.judged) - 288, "今の回のお手本の 1 小節前から")
	frames(m, 2)
	ok(m.play.sim.tick > TL.call_start(m.play.sim.judged) - 288, "続けると進む")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "フォーカスが外れると一時停止(E-9)")
	_done(m)
	return true


func test_pause_settings_back() -> bool:
	var m := _main()
	_to_play(m)
	press(m, KEY_ESCAPE)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "settings", "一時停止から設定")
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)  # 揺れを切る(上から 音量・揺れ・点滅)
	eq(m.store.settings()["shake"], false, "揺れを切って保存")
	press(m, KEY_ESCAPE)
	eq(m.screen, "play", "戻ると一時停止へ")
	ok(m.pause_view != null and m.pause_view.visible, "一時停止の画面")
	eq(m.play.shake_on, false, "設定がプレイに届く")
	_done(m)
	return true


func test_settings_volume_reaches_bus() -> bool:
	var m := _main()
	press(m, KEY_X)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "settings", "S1 から設定")
	press(m, KEY_RIGHT)  # 75 → 100
	eq(int(m.store.settings()["volume"]), 100, "音量の段")
	press(m, KEY_RIGHT)  # 100 → 0
	ok(AudioServer.is_bus_mute(0), "音量 0 はバスを消音(伴奏・お手本・押した音の全部。FR-21)")
	press(m, KEY_RIGHT)
	ok(not AudioServer.is_bus_mute(0), "25 で戻る")
	press(m, KEY_ESCAPE)
	eq(m.screen, "title", "戻る")
	_done(m)
	return true


func test_ac20_no_shake_when_off() -> bool:
	var m := _main()
	m.store.set_setting("shake", false)
	_to_play(m)
	m.play._on_event({"type": "turn_miss", "turn": 0, "lives": 2})
	frames(m, 3, 0.0)
	eq(m.play.position, Vector2.ZERO, "揺れを切ると動かない")
	m.play.shake_on = true
	m.play._on_event({"type": "turn_miss", "turn": 0, "lives": 2})
	var moved := false
	for k in 5:
		frames(m, 1, 0.0)
		moved = moved or m.play.position != Vector2.ZERO
	ok(moved, "入なら揺れる")
	_done(m)
	return true


func test_fr25_enter_skips_song() -> bool:
	var m := _main()
	_to_play(m)
	press(m, KEY_ENTER)
	eq(m.screen, "play", "自分の曲の前の Enter は何もしない")
	var bot := Bots.new(Bots.EXACT)
	while m.play.sim.tick < B.SONG_START + 10:
		bot.act(m.play.sim)
		m.play.sim.step()
	frames(m, 1, 0.0)
	press(m, KEY_ENTER)
	eq(m.screen, "result", "自分の曲の間の Enter で結果へ")
	eq(m.current.share.split("\n")[1], "8 小節 / 外れ 0 回 / ぴったり 39 / 18,100点", "飛ばしても最後まで行った扱い")
	_done(m)
	return true


func test_events_drive_sounds_and_layers() -> bool:
	var m := _main()
	_to_play(m)
	var before: int = Notes.played
	frames(m, 60 * 3)  # 数え(クリック 4 回)と回 1 のお手本(4 音)
	ok(Notes.played - before >= 6, "数えのクリック 5 回とお手本の 1 音目(%d)" % (Notes.played - before))
	var bot := Bots.new(Bots.EXACT)
	m.play.bot = bot
	frames(m, 60 * 5)  # 回 1 の判定(796)と、次の小節の頭(864)を過ぎる
	eq(m.play.sim.layers, 1, "回 1 が合って層 1")
	eq(Music.layers, 1, "次の小節の頭から伴奏の層が鳴る")
	_done(m)
	return true


func test_e8_behind_pauses_after_1s() -> bool:
	var m := _main()
	_to_play(m)
	m.play._process(1.0)  # 120 tick 離れる → 16 だけ進める
	eq(m.play.sim.tick, 16, "1 フレーム 16 tick まで")
	for k in 70:
		m.play._free += 100.0  # 追いつけない状態を 1 秒以上続ける
		m.play._process(0.0)
		OS.delay_msec(16)
		if m.pause_view != null:
			break
	ok(m.pause_view != null, "追いつけない状態が 1 秒続いたら一時停止")
	_done(m)
	return true


func test_gate_touch_and_ime() -> bool:
	var m := _main()
	var t := InputEventScreenTouch.new()
	t.pressed = true
	m._input(t)
	eq(m.screen, "gate", "タッチでは進まない")
	ok(m._touch_note.visible, "キーボードで遊ぶ案内が出る(FR-26)")
	press(m, KEY_X)
	press(m, KEY_ENTER)
	m._input(kev(0))
	frames(m, 1, 0.0)
	ok(m.play._ime.visible, "physical_keycode が 0 なら日本語入力の案内(共通 §3 の 9)")
	_done(m)
	return true


func test_result_ignores_modifier_keys() -> bool:
	var m := _main()
	_to_play(m)
	_finish(m)
	m.current._shown_at -= 1000
	frames(m, 1)
	var e := kev(KEY_R)
	e.ctrl_pressed = true
	m._input(e)
	eq(m.screen, "result", "Ctrl 付きの R ではもう1回にならない")
	_done(m)
	return true


func test_title_keys_play() -> bool:
	var m := _main()
	press(m, KEY_X)
	var before: int = Notes.played
	press(m, KEY_K)
	eq(Notes.played, before + 1, "S1 でも押すと鳴る(試し弾き)")
	eq(m.screen, "title", "メニューは動かない")
	_done(m)
	return true
