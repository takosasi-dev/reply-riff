# 画面の流れのテスト(AC-18〜AC-20・FR-3・FR-17・FR-22〜FR-26・E-1・E-8・NFR-2)。main.tscn を木に置き、キーのイベントを直接渡す。
# フレームは _process を呼んで進める。プレイはフレームの時間で進める(曲の位置の時計は test_music で別に見る)。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Play := preload("res://ui/play.gd")
const Kit := preload("res://ui/kit.gd")


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
	for k in 99:  # §8.2: 100 回の中央値と 95% 値(Godot の中だけ)
		m._input(kev(KEY_A if k % 2 == 0 else KEY_S))
		m._input(kev(KEY_A if k % 2 == 0 else KEY_S, false))
	var lat: Array = m.play.key_lat_us.duplicate()
	lat.sort()
	eq(lat.size(), 100, "100 回")
	ok(int(lat[-1]) < 16700, "最大も 1 フレーム以内(NFR-2)")
	print("  押してから鳴らす呼び出しまで(100 回): 中央値 %d usec / 95%% 値 %d usec / 最大 %d usec" % [lat[50], lat[94], lat[-1]])
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


func test_fr25_enter_before_last_judge() -> bool:
	# 回 8 の最後の音が位置 7 なら判定は 4900(E-6)。自分の曲の頭 4896〜4899 の Enter では飛ばさない
	var m := _main()
	_to_play(m)
	m.play.sim.phrase[7] = {"pos": [1, 2, 3, 4, 5, 7], "keys": [0, 0, 0, 0, 0, 0], "hint": 0}
	var bot := Bots.new(Bots.EXACT)
	while m.play.sim.tick < B.SONG_START + 2:
		bot.act(m.play.sim)
		m.play.sim.step()
	frames(m, 1, 0.0)
	eq(m.play.sim.judged, 7, "回 8 はまだ判定していない")
	press(m, KEY_ENTER)
	eq(m.screen, "play", "回 8 の判定の前は飛ばさない")
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
	eq(m.current.share.split("\n")[1], "8 小節 / 外れ 0 回 / ぴったり 39 / 18,100点(ワンマン)", "飛ばしても最後まで行った扱い")
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


# 磨き(2026-11-20): タイトルは前に選んだボタンを覚えている(設定から戻ると設定のまま)。
func test_title_remembers_selection() -> bool:
	var m := _main()
	press(m, KEY_X)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "settings", "↓↓ Enter で設定")
	press(m, KEY_ESCAPE)
	eq(m.screen, "title", "Esc でタイトル")
	eq(m.current.menu.sel, 2, "設定のボタンが選ばれたまま")
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(int(m.run["mode"]), 1, "↓↓ で練習")
	m.play.frame_clock = true
	_finish(m)
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)  # 結果のタイトルへ
	eq(m.screen, "title", "結果からタイトルへ")
	eq(m.current.menu.sel, 1, "練習のボタンが選ばれたまま")
	_done(m)
	return true


# 磨き(2026-11-20): 回の結果の印は turn_ok・turn_miss で伸び、もう1回で消える。判定の後は、比べる印のために judge を持つ。
func test_turn_results_and_judge_kept() -> bool:
	var m := _main()
	_to_play(m)
	var p: Play = m.play
	p._on_event({"type": "judge", "turn": 0, "grades": [0, 0, 0, 0], "pos": [0, 2, 4, 5], "keys": [3, 3, 3, 3], "presses": [], "points": 1700})
	p._on_event({"type": "turn_ok", "turn": 0, "layers": 1})
	p._on_event({"type": "turn_miss", "turn": 1, "lives": 2})
	eq(p._results, [true, false], "合った・外れの順に並ぶ")
	eq(int(p._judge["turn"]), 0, "最後の判定を持つ")
	eq(p._gain_text, "+1,700", "入った点の文字")
	ok(p._life_lost_at > 0, "残機を失った時刻")
	m._again()
	eq(m.play._results, [], "もう1回で消える")
	ok(m.play._judge.is_empty(), "判定も消える")
	_done(m)
	return true


# 磨き(2026-11-20): 一時停止から戻った直後の 1 小節(判定済みの回の返し)は、数えとして見せる。点滅を弱めると新しい光も 20% 以下。
func test_resume_lead_in_and_reduced_flash() -> bool:
	var m := _main()
	_to_play(m)
	frames(m, 60 * 7)  # 回 1 の判定を過ぎ、回 2 のお手本の途中まで
	press(m, KEY_ESCAPE)
	press(m, KEY_ESCAPE)
	var p: Play = m.play
	eq(TL.section(p.sim.tick), TL.REPLY, "戻った先は回 1 の返しの小節")
	eq(p._view_section(), TL.COUNT, "画面では数えとして見せる")
	eq(p._head.text, "", "見出し「弾き返す」を出さない")
	eq(p._bar["turn"].text, "回 2/8", "上の帯は次に返す回")
	frames(m, 60 * 3)
	eq(TL.section(p.sim.tick), TL.CALL, "次の小節はお手本")
	eq(p._view_section(), TL.CALL, "お手本に入ったら元に戻る")
	p.reduce_flash = true
	ok(p._flash(1.0) <= B.REDUCED_FLASH_ALPHA and p._flash(0.1) <= 0.1, "点滅を弱めると光は 20% 以下")
	_done(m)
	return true


# v0.3.0: 画面の切り替わりは見た目だけ。画面と入力はすぐ次へ行き、前の画面は動かず押せないまま幕が暗くなり切るまで残る。
func test_transition_is_visual_only() -> bool:
	var m := _main()
	press(m, KEY_X)
	eq(m.screen, "title", "キーですぐタイトル")
	ok(m.curtain.active(), "幕が動いている")
	eq(m._pending, m.current, "新しい画面は幕が暗くなり切るまで透明")
	eq(m.current.modulate.a, 0.0, "透明")
	eq(m._ghosts.size(), 1, "前の画面(S0)が残る")
	eq(m._ghosts[0].process_mode, Node.PROCESS_MODE_DISABLED, "前の画面は動かない")
	press(m, KEY_ENTER)
	var first: Node = m.play
	press(m, KEY_ENTER)
	press(m, KEY_ENTER)
	eq(m.screen, "play", "動いている間の Enter でも今日の曲に入る")
	ok(m.play == first, "連打しても 2 回始まらない")
	eq(m._ghosts.size(), 1, "前の画面は最後の 1 つだけ(古い物はすぐ消す)")
	m.curtain._at -= 1000  # 幕が暗くなり切った後
	m._process(0.0)
	eq(m._ghosts.size(), 0, "暗くなり切ったら前の画面を消す")
	eq(m.play.modulate.a, 1.0, "新しい画面を見せる")
	ok(m.curtain._out == B.TRANS_PLAY_OUT_MS and m.curtain._in == B.TRANS_PLAY_IN_MS, "プレイに入る時は短い動き")
	_done(m)
	return true


# v0.3.0: 点滅を弱めると動きも減らす(切り替わりは 150 ms のフェードだけ・数え上げで跳ねない)。
func test_reduce_flash_calms_motion() -> bool:
	var m := _main()
	ok(not Kit.calm, "既定は動く")
	m.store.set_setting("reduce_flash", true)
	m._apply_settings()
	ok(Kit.calm, "点滅を弱める → 動きを減らす")
	press(m, KEY_X)
	eq(m.curtain._out, 0, "前の画面を暗くする間は無し")
	eq(m.curtain._in, Kit.Curtain.CALM_MS, "150 ms のフェード")
	press(m, KEY_ENTER)
	m.play.sim.points = 500
	m.play._refresh()
	eq(m.play._bar["points"].scale, Vector2.ONE, "点が増えても跳ねない")
	_done(m)
	Kit.calm = false
	return true


# v0.3.0: 上の帯の点は数え上がって跳ねる。
func test_points_roll_and_bump() -> bool:
	var m := _main()
	_to_play(m)
	var p: Play = m.play
	p.sim.points = 1000
	p._refresh()
	ok(p._bar["points"].scale.x > 1.1, "増えた瞬間に跳ねる(%s)" % p._bar["points"].scale)
	eq(p._bar["points"].text, "0点", "数え上げの始め")
	p._pts_at -= 1000
	p._refresh()
	eq(p._bar["points"].text, "1,000点", "数え上げの終わり")
	eq(p._bar["points"].scale, Vector2.ONE, "跳ね終わる")
	_done(m)
	return true


# v0.3.0: 新しい記録の時だけ祝う(判子と紙吹雪)。同じ点・0 点では祝わない。
func test_result_celebrates_new_best() -> bool:
	var m := _main()
	_to_play(m)
	var bot := Bots.new(Bots.EXACT)
	while not m.play.sim.is_over():
		bot.act(m.play.sim)
		m.play.sim.step()
	m.play.finished.emit(m.play.sim.result())
	ok(m.current.celebrate, "初めての点は新しい記録")
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_ENTER)  # もう1回(同じ曲)
	_finish(m)  # 何も押さない
	ok(not m.current.celebrate, "0 点は祝わない")
	eq(m.current.menu.sel, 0, "もう1回に最初から合わせてある")
	_done(m)
	return true


# v0.3.1: 段位の看板。点から出し、点が数え上がってから出る。新しい記録の判子と場所が重ならない。
# 点滅を弱める(動きを減らす)と、出た時から止まった形(吊り下がり済み・電球は全部)。もう1回へのフォーカスは変えない。
func test_result_rank_sign() -> bool:
	var m := _main()
	_to_play(m)
	var bot := Bots.new(Bots.EXACT)
	while not m.play.sim.is_over():
		bot.act(m.play.sim)
		m.play.sim.step()
	m.play.finished.emit(m.play.sim.result())
	var r: Control = m.current
	eq(r.rank, B.RANK_POINTS.size(), "18,100 点はいちばん上")
	ok(r.celebrate, "新しい記録でもある")
	ok(not r.rank_rect().intersects(r.badge_rect()), "18,100 点: 看板と判子が重ならない")
	ok(not r.rank_shown(B.COUNT_MS - 1) and r.rank_shown(B.COUNT_MS), "点が数え上がってから出る")
	eq(r.rank_k(B.COUNT_MS), 0.0, "出た時は吊り下がり始め")
	eq(r.rank_k(B.COUNT_MS + B.RANK_DROP_MS), 1.0, "揺れが止まる")
	eq(r.rank_lit(B.COUNT_MS), 0, "電球はまだ")
	eq(r.rank_lit(100000), r.rank + 1, "電球は段 + 1 個")
	ok(B.COUNT_MS + B.RANK_DROP_MS + r.rank * B.RANK_BULB_MS < B.COUNT_MS + B.TURNS * B.TALLY_STEP_MS, "電球は判子より前に灯り終える(同時に言わない)")
	eq(r.menu.sel, 0, "もう1回に合わせたまま")
	r._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_ENTER)
	_finish(m)  # 何も押さない = 0 点
	r = m.current
	eq(r.rank, 0, "0 点はいちばん下")
	ok(not r.rank_rect().intersects(r.badge_rect()), "0 点: 看板と判子の場所が重ならない")
	Kit.calm = true
	eq(r.rank_k(B.COUNT_MS), 1.0, "動きを減らす: 吊り下がり済み")
	eq(r.rank_lit(B.COUNT_MS), r.rank + 1, "動きを減らす: 電球は全部")
	ok(not r.rank_shown(B.COUNT_MS - 1), "動きを減らしても、点が数え上がってから")
	Kit.calm = false
	eq(r.menu.sel, 0, "もう1回に合わせたまま")
	_done(m)
	return true
