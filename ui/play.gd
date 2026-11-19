# S2 プレイ(画面設計書 §3)。曲の位置から目標の tick を求めて sim を進め(1 フレーム 16 tick まで。D-11・E-7・E-8)、
# events で音と演出を出し(§9.12)、snapshot から上の帯・小節の目盛り・判定の印・鍵盤を描く。ゲームの決まりは持たない(INV-1)。
# 押したキーはそのフレームで音を鳴らしてから sim.queue_press に渡す(FR-3)。押されているキーの組は ui が持つ(共通 §3 の 5)。
extends Control

signal finished(result: Dictionary)
signal pause_requested

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const TL := preload("res://core/timeline.gd")
const Sim := preload("res://core/sim.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")

var sim: Sim = null
var mode := 0
var seed_value := 1
var paused := false
var shake_on := true
var reduce_flash := false
var frame_clock := false  # 真ならフレームの時間で進める(テストと smoke)。偽なら曲の位置で進める
var bot: RefCounted = null  # 自動の確かめ(smoke)の時だけ。step ごとに act(sim) を呼ぶ
var held := {}  # 押されている鍵の番号 → 押した時刻(ms)
var key_lat_us: Array = []  # 押すイベントを受けてから音を鳴らす呼び出しまで(usec。NFR-2)

var _free := 0.0  # 目標の tick(小数)
var _layers := 0  # sim の層(turn_ok の events から。音の側へは小節の頭で移す)
var _behind_since := -1
var _over_at := -1
var _over_text := ""
var _shake_until := 0
var _snap := {}
var _song_lit := {}  # 鍵 → [時刻, 自分の音か]
var _beat_at := -100000
var _beat_n := 0
var _turn_text := ""
var _turn_at := -100000
var _tag_at := -100000
var _tag_layer := -1
var _section := -1
var _section_at := 0
var _ime_until := 0
var _bar := {}
var _head: Label
var _turn_label: Label
var _center: Label
var _skip: Label
var _ime: Label


func _ready() -> void:
	size = Vector2(1280, 720)
	var esc := Kit.place(Kit.button("Esc", S.ESC, 20), 24, 12, 72, 40)
	esc.pressed.connect(func() -> void: pause_requested.emit())
	add_child(esc)
	for k: String in ["turn", "points"]:
		var l := Kit.label("", 26, Kit.C_TEXT, 700)
		add_child(l)
		_bar[k] = l
	_bar["turn"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	Kit.place(_bar["turn"], 116, 8, 160, 48)
	_bar["points"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Kit.place(_bar["points"], 1000, 8, 256, 48)
	_head = Kit.label("", 36, Kit.C_TEXT, 700)
	add_child(Kit.place(_head, 0, 76, 1280, 56))
	_turn_label = Kit.label("", 28, Kit.C_TEXT, 700)
	add_child(Kit.place(_turn_label, 0, 128, 1280, 44))
	_center = Kit.label("", 72, Kit.C_TEXT, 800)
	add_child(Kit.place(_center, 0, 320, 1280, 110))
	_skip = Kit.label(S.SKIP, 20, Kit.C_DIM, 500)
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(Kit.place(_skip, 900, 670, 356, 36))
	_ime = Kit.label(S.IME, 22, Kit.C_WARN, 700)
	_ime.visible = false
	add_child(Kit.place(_ime, 0, 420, 1280, 40))


func start(p_mode: int, p_seed: int) -> void:
	mode = p_mode
	seed_value = p_seed
	sim = Sim.new(p_seed, p_mode)
	paused = false
	held.clear()
	_free = 0.0
	_over_at = -1
	_song_lit.clear()
	_layers = 0
	Music.set_layers(0)
	if not frame_clock:
		Music.start_at(0)
	_refresh()


func is_playing() -> bool:
	return sim != null and not sim.is_over() and _over_at == -1


# S2 のキー(画面設計書 §7)。Esc は一時停止、8 キーは鍵盤、自分の曲の間の Enter は飛ばす。ほかは何もしない。
func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		pause_requested.emit()
		return
	if not is_playing() or paused:
		return
	var i := Keymap.index_of(ev)
	if i < 0:
		if ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and int(_snap.get("section", -1)) == TL.SONG and int(_snap["judged"]) >= B.TURNS:
			skip_song()  # FR-25
		elif ev.pressed and ev.physical_keycode == 0:
			_ime_until = Time.get_ticks_msec() + B.IME_NOTE_MS  # 共通 §3 の 9
		return
	if not ev.pressed:
		held.erase(i)
		return
	if ev.echo or Keymap.has_modifier(ev):
		return  # FR-24
	var t0 := Time.get_ticks_usec()
	Notes.play_key(i)  # 押したフレームに鳴らす(sim を待たない)
	if key_lat_us.size() < 1000:
		key_lat_us.append(Time.get_ticks_usec() - t0)
	held[i] = Time.get_ticks_msec()
	sim.queue_press(i)


func skip_song() -> void:
	Music.stop()
	_over_at = -2
	finished.emit(sim.result())


# 一時停止・フォーカスが外れた時(共通 §3 の 5)。押されている組を空にする。
func cancel_input() -> void:
	held.clear()


func pause_music() -> void:
	Music.pause()


# 一時停止から戻る(D-13・FR-22)。今の回のお手本の 1 小節前へ sim を戻し、曲をその位置へ移して鳴らす。
func resume() -> void:
	sim.rewind_to_turn()
	_free = sim.tick
	_behind_since = -1
	Music.set_layers(_layers)
	if not frame_clock:
		Music.start_at(sim.tick)
	paused = false
	_refresh()


func _process(delta: float) -> void:
	if sim == null:
		return
	var now := Time.get_ticks_msec()
	position = Vector2.ZERO
	if shake_on and now < _shake_until:
		position = Vector2(randf_range(-B.SHAKE_PX, B.SHAKE_PX), randf_range(-B.SHAKE_PX, B.SHAKE_PX))
	_ime.visible = now < _ime_until
	if _over_at >= 0:
		if now - _over_at >= B.OVER_MS:
			_over_at = -2
			finished.emit(sim.result())
		_refresh()
		return
	if paused or _over_at == -2:
		return
	# 曲の位置は毎フレーム読む(くり返しの回数と「止まっていないか」はここで更新される)
	var music_tick := 0.0 if frame_clock else Music.song_sec() * B.TICK_HZ
	if frame_clock or Music.stalled():
		_free += delta * B.TICK_HZ
	else:
		_free = music_tick
	var n := floori(_free) - sim.tick  # 目標が前なら進めない(E-7)
	if n > B.MAX_STEPS_PER_FRAME:
		n = B.MAX_STEPS_PER_FRAME  # E-8: 残りは次のフレームで追う
		if _behind_since < 0:
			_behind_since = now
		elif now - _behind_since >= B.BEHIND_PAUSE_MS:
			_behind_since = -1
			pause_requested.emit()
			return
	else:
		_behind_since = -1
	for k in maxi(n, 0):
		if bot != null:
			bot.act(sim)
		sim.step()
		for e: Dictionary in sim.events():
			_on_event(e)
		if sim.is_over():
			break
	_refresh()


# 演出の表(§9.12)。events を受けたフレームに始める(FR-15)。
func _on_event(e: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	match e["type"]:
		"beat":
			_beat_at = now
			_beat_n = e["beat"]
			if e["beat"] == 0:
				Music.set_layers(_layers)  # 層は判定の後、次の小節の頭から(§9.4)
			if Music.layers == 0:
				Notes.play("click")
		"call_note":
			Notes.play_key(e["key"])
		"turn_ok":
			_turn_text = S.TURN_OK
			_turn_at = now
			_layers = int(e["layers"])
			_tag_layer = _layers - 1
			_tag_at = now
		"turn_miss":
			_turn_text = S.TURN_MISS
			_turn_at = now
			Notes.play("miss")
			_shake_until = now + B.SHAKE_MS
		"song_note":
			Notes.play_key(e["key"], not e["own"])
			_song_lit[e["key"]] = [now, e["own"]]
		"over":
			Notes.play("over")
			Music.stop()
			_over_text = S.OVER_DONE if e["reason"] == "end" else S.OVER_STOP
			_over_at = now


func _refresh() -> void:
	_snap = sim.snapshot()
	var now := Time.get_ticks_msec()
	var sec: int = _snap["section"]
	if sec != _section:
		_section = sec
		_section_at = now
	_bar["turn"].text = S.BAR_SONG if sec >= TL.SONG else S.BAR_TURN % (maxi(int(_snap["turn"]), 0) + 1)
	_bar["points"].text = S.BAR_POINTS % Score.comma(int(_snap["points"]))
	match sec:
		TL.CALL:
			_head.text = S.HEAD_CALL
		TL.REPLY:
			_head.text = S.HEAD_REPLY
		TL.SONG, TL.END:
			_head.text = S.HEAD_SONG
		_:
			_head.text = ""
	_head.modulate.a = clampf(float(now - _section_at) / B.HEAD_FADE_MS, 0.0, 1.0)  # 区間が変わる時に 200 ms で入れ替える
	_turn_label.text = _turn_text if now - _turn_at < B.RESULT_MS else ""
	_turn_label.add_theme_color_override("font_color", Kit.C_PERFECT if _turn_text == S.TURN_OK else Kit.C_MISS)
	if _over_at >= 0:
		_center.text = _over_text
	elif sec == TL.COUNT:
		_center.text = str(_beat_n + 1)  # 数え: 1・2・3・4
	else:
		_center.text = ""
	_skip.visible = sec == TL.SONG and _over_at == -1
	queue_redraw()


func _flash(a: float) -> float:
	return minf(a, B.REDUCED_FLASH_ALPHA) if reduce_flash else a


func _draw() -> void:
	if _snap.is_empty():
		return
	var now := Time.get_ticks_msec()
	var f := Kit.font(700)
	# 上の帯: 残機(丸。失った物は線だけ)と層の札(鳴っている層は塗る)
	for k in B.LIVES:
		var c := Vector2(300 + 34 * k, 32)
		if k < int(_snap["lives"]):
			draw_circle(c, 11, Kit.C_TEXT)
		else:
			draw_arc(c, 11, 0, TAU, 24, Kit.C_TEXT, 2.0, true)
	for k in B.MAX_LAYERS:
		var r := Rect2(430 + 136 * k, 14, 124, 36)
		var on := k < Music.layers
		draw_rect(r, Color(Kit.C_LAYER, 0.85) if on else Color(1, 1, 1, 0.03))
		draw_rect(r, Kit.C_LAYER, false, 2.0)
		if k == _tag_layer and now - _tag_at < B.TAG_LIT_MS:
			var a := _flash(1.0 - float(now - _tag_at) / B.TAG_LIT_MS)
			draw_rect(r.grow(5), Color(Kit.C_LAYER, a), false, 4.0)
		draw_string(f, Vector2(r.position.x, r.position.y + 26), S.LAYER_NAMES[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Kit.C_BG if on else Kit.C_LAYER)
	# 小節の目盛り: 8 つの位置(拍は大きい点)と、今の位置の縦線
	var y := B.RULER_Y
	var step := (B.RULER_X1 - B.RULER_X0) / B.BAR_EIGHTHS
	draw_line(Vector2(B.RULER_X0, y), Vector2(B.RULER_X1, y), Kit.C_RULER, 2.0)
	var beat_lit := now - _beat_at < B.BEAT_LIT_MS
	for i in B.BAR_EIGHTHS:
		var at := Vector2(B.RULER_X0 + step * i, y)
		draw_circle(at, 7.0 if i % 2 == 0 else 4.0, Kit.C_RULER)
		if beat_lit and i == _beat_n * 2:
			draw_circle(at, 9.0, Color(Kit.C_NOW, _flash(0.9)))
	var sec: int = _snap["section"]
	if sec != TL.END:
		var x := B.RULER_X0 + (B.RULER_X1 - B.RULER_X0) * float(int(_snap["tick"]) % B.BAR_TICKS) / B.BAR_TICKS
		draw_line(Vector2(x, y - 26), Vector2(x, y + 26), Kit.C_NOW, 3.0)
	for p: int in _snap["call_pos"]:
		Kit.draw_diamond(self, Vector2(B.RULER_X0 + step * p, y + 40), 10.0, Kit.C_CALL)
	for m: Array in _snap["marks"]:
		Kit.draw_grade(self, Vector2(B.RULER_X0 + step * int(m[0]), y + 80), int(m[1]))
	# 鍵盤: 押した鍵は沈んで中を塗る。手がかりは縁だけを光らせる。自分の曲は鳴った鍵を塗る(お手本は薄く)
	var lit: Array = _snap["lit"]
	for k in B.KEYS_N:
		var sink := 0.0
		var fill := 0.0
		if held.has(k):
			sink = clampf(float(now - int(held[k])) / B.KEY_SINK_MS, 0.0, 1.0)
			fill = 1.0
		if _song_lit.has(k):
			var t := float(now - int(_song_lit[k][0])) / B.KEY_LIT_MS
			if t < 1.0:
				fill = maxf(fill, _flash((1.0 if _song_lit[k][1] else 0.35) * (1.0 - t)))
		Kit.draw_key(self, k, Kit.key_rect(k), sink, fill, lit.has(k), _flash(1.0))
