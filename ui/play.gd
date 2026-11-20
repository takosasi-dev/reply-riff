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
var _judge := {}  # 最後の判定(events の judge)と、受けた時刻 at
var _results: Array = []  # 回ごとに合ったか(events の turn_ok・turn_miss)
var _life_lost_at := -100000
var _layer_on_at := -100000  # 音の側の層が増えた時刻(小節の頭)
var _gain_text := ""
var _gain_at := -100000
var _song_dots: Array = []  # 自分の曲の今の小節で鳴った音 [8 分音符の位置, キー, 自分の音か]
var _song_bar := -1
var _lead_in := false  # 一時停止から戻った直後の 1 小節(判定済みの前の回の返しの小節)。数えとして見せる
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
	add_child(Kit.place(_center, 0, 350, 1280, 110))  # 段の印(〜y 340)と重ならない高さ
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
	_judge = {}
	_results.clear()
	_song_dots.clear()
	_song_bar = -1
	_turn_at = -100000
	_gain_at = -100000
	_tag_layer = -1
	_lead_in = false
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
	_song_dots.clear()
	_lead_in = sim.judged > 0 and sim.judged < B.TURNS
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
	for l: Label in [_head, _turn_label, _center]:
		l.visible = not paused  # 一時停止の見出しと重ねない
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
				var before := Music.layers
				Music.set_layers(_layers)  # 層は判定の後、次の小節の頭から(§9.4)
				if Music.layers > before:
					_layer_on_at = now  # 増えた層の札が、鳴り始めた小節の頭で膨らむ
			if Music.layers == 0:
				Notes.play("click")
		"call_note":
			Notes.play_key(e["key"])
		"judge":
			_judge = e.duplicate()
			_judge["at"] = now
			if int(e["points"]) > 0:
				_gain_text = S.GAIN % Score.comma(int(e["points"]))
				_gain_at = now
		"turn_ok":
			_turn_text = S.TURN_OK
			_turn_at = now
			_results.append(true)
			_layers = int(e["layers"])
			_tag_layer = _layers - 1
			_tag_at = now
		"turn_miss":
			_turn_text = S.TURN_MISS
			_turn_at = now
			_results.append(false)
			_life_lost_at = now
			Notes.play("miss")
			_shake_until = now + B.SHAKE_MS
		"song_note":
			Notes.play_key(e["key"], not e["own"])
			_song_lit[e["key"]] = [now, e["own"]]
			var at := sim.tick - 1 - B.SONG_START  # events は tick を進める前に出る
			@warning_ignore("integer_division")
			var bar := at / B.BAR_TICKS
			if bar != _song_bar:
				_song_bar = bar
				_song_dots.clear()
			_song_dots.append([float(at % B.BAR_TICKS) / B.EIGHTH_TICKS, int(e["key"]), bool(e["own"])])
		"over":
			Notes.play("over")
			Music.stop()
			_over_text = S.OVER_DONE if e["reason"] == "end" else S.OVER_STOP
			_over_at = now


func _refresh() -> void:
	_snap = sim.snapshot()
	var now := Time.get_ticks_msec()
	if _lead_in and int(_snap["section"]) != TL.REPLY:
		_lead_in = false
	var sec := _view_section()
	if sec != _section:
		_section = sec
		_section_at = now
	_bar["turn"].text = S.BAR_SONG if sec >= TL.SONG else S.BAR_TURN % ((int(_snap["judged"]) if _lead_in else maxi(int(_snap["turn"]), 0)) + 1)
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
	_head.add_theme_color_override("font_color", _section_color(sec))  # お手本は黄、自分の番は青(印と同じ色)
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


# 画面で見せる区間。一時停止から戻った直後の 1 小節は、返しではなく数えとして見せる(押しても判定しない小節なので)。
func _view_section() -> int:
	return TL.COUNT if _lead_in else int(_snap["section"])


func _flash(a: float) -> float:
	return minf(a, B.REDUCED_FLASH_ALPHA) if reduce_flash else a


static func _section_color(sec: int) -> Color:
	match sec:
		TL.CALL:
			return Kit.C_CALL
		TL.REPLY:
			return Kit.C_PRESS
	return Kit.C_TEXT


# 小節の目盛りの上の x。at は 8 分音符の何番目(小数でよい。目盛りの外にもはみ出せる)。
static func _ruler_x(at: float) -> float:
	return B.RULER_X0 + (B.RULER_X1 - B.RULER_X0) * at / B.BAR_EIGHTHS


# 押した音の印: 青い丸の中にキーの文字。own が偽なら(自分の曲のお手本の音)灰色の輪。
func _press_dot(at: Vector2, k: int, own: bool = true, a: float = 1.0) -> void:
	if own:
		draw_circle(at, B.DOT_R, Color(Kit.C_PRESS, a))
	else:
		draw_arc(at, B.DOT_R - 1, 0, TAU, 32, Color(Kit.C_DIM, a), 2.0, true)
	draw_string(Kit.font(800), Vector2(at.x - B.DOT_R, at.y + 6), S.KEYS[k], HORIZONTAL_ALIGNMENT_CENTER, B.DOT_R * 2, 17, Color(Kit.C_BG, a) if own else Color(Kit.C_DIM, a))


func _draw() -> void:
	if _snap.is_empty():
		return
	var now := Time.get_ticks_msec()
	var f := Kit.font(700)
	var tick: int = _snap["tick"]
	var sec := _view_section()
	# 上の帯: 残機(丸。失った物は線だけ。失った時は赤い輪が広がる)
	for k in B.LIVES:
		var c := Vector2(300 + 34 * k, 32)
		if k < int(_snap["lives"]):
			draw_circle(c, 11, Kit.C_TEXT)
		else:
			draw_arc(c, 11, 0, TAU, 24, Kit.C_TEXT, 2.0, true)
		if k == int(_snap["lives"]) and now - _life_lost_at < B.LIFE_LOST_MS:
			var t := float(now - _life_lost_at) / B.LIFE_LOST_MS
			draw_arc(c, 11 + 14 * t, 0, TAU, 32, Color(Kit.C_MISS, _flash(1.0 - t)), 3.0, true)
	# 層の札: 鳴っている層は塗る。合った後、次の小節の頭までは薄く塗って待つ。鳴り始めたら膨らむ。鳴っている札は拍で明るくなる
	var beat_t := float(now - _beat_at) / B.BEAT_LIT_MS
	for k in B.MAX_LAYERS:
		var r := Rect2(430 + 136 * k, 14, 124, 36)
		var on := k < Music.layers
		if on and k == Music.layers - 1 and now - _layer_on_at < B.TAG_POP_MS:
			r = r.grow(B.TAG_POP_PX * (1.0 - float(now - _layer_on_at) / B.TAG_POP_MS))
		var fill := Color(Kit.C_LAYER, 0.85) if on else (Color(Kit.C_LAYER, 0.3) if k < _layers else Color(1, 1, 1, 0.03))
		draw_rect(r, fill)
		if on and beat_t < 1.0:
			draw_rect(r, Color(1, 1, 1, _flash(0.22 * (1.0 - beat_t))))
		draw_rect(r, Kit.C_LAYER, false, 2.0)
		if k == _tag_layer and now - _tag_at < B.TAG_LIT_MS:
			var a := _flash(1.0 - float(now - _tag_at) / B.TAG_LIT_MS)
			draw_rect(r.grow(5), Color(Kit.C_LAYER, a), false, 4.0)
		draw_string(f, Vector2(r.position.x, r.position.y + r.size.y / 2 + 8), S.LAYER_NAMES[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Kit.C_BG if on else Kit.C_LAYER)
	# 入った点(判定の後、点の下に浮かんで消える)
	if now - _gain_at < B.GAIN_MS:
		var t := float(now - _gain_at) / B.GAIN_MS
		draw_string(f, Vector2(1000, 76 - 12 * t), _gain_text, HORIZONTAL_ALIGNMENT_RIGHT, 256, 22, Color(Kit.C_PERFECT, 1.0 - t * t))
	# 小節の目盛り: 8 つの位置(拍は大きい点)と、今の位置の縦線(お手本の間は黄、返しの間は青)
	var y := B.RULER_Y
	var step := (B.RULER_X1 - B.RULER_X0) / B.BAR_EIGHTHS
	draw_line(Vector2(B.RULER_X0, y), Vector2(B.RULER_X1, y), Kit.C_RULER, 2.0)
	var beat_lit := now - _beat_at < B.BEAT_LIT_MS
	for i in B.BAR_EIGHTHS:
		var at := Vector2(B.RULER_X0 + step * i, y)
		draw_circle(at, 7.0 if i % 2 == 0 else 4.0, Kit.C_RULER)
		if beat_lit and i == _beat_n * 2:
			draw_circle(at, 9.0, Color(_section_color(sec), _flash(0.9)))
	if sec != TL.END:
		var x := _ruler_x(float(tick % B.BAR_TICKS) / B.EIGHTH_TICKS)
		draw_line(Vector2(x, y - 26), Vector2(x, y + 26), _section_color(sec), 3.0)
	var row := y + B.ROW_DY
	# 1 段目: お手本の間は、鳴った音の位置に ◆。返しの間は、押した位置に青い丸(押したキーの文字)
	if sec == TL.CALL:
		for p: int in _snap["call_pos"]:
			Kit.draw_diamond(self, Vector2(_ruler_x(p), row), 10.0, Kit.C_CALL)
	var judged: int = _snap["judged"]
	if judged < B.TURNS:
		for p: Array in _snap["presses"]:
			_press_dot(Vector2(_ruler_x(float(int(p[0]) - TL.reply_start(judged)) / B.EIGHTH_TICKS), row), int(p[1]))
	# 判定の後: 同じ返しの小節の間は、お手本の位置(◇)と押した位置を並べて比べる。段の印とお手本のキーは、次の返しが始まるまで出す
	if not _judge.is_empty() and not _lead_in:
		var jt: int = _judge["turn"]
		var fresh := now - int(_judge["at"]) < B.RESULT_MS
		if sec == TL.REPLY and TL.turn_of(tick) == jt:
			for p: int in _judge["pos"]:
				Kit.draw_diamond(self, Vector2(_ruler_x(p), row), B.DOT_R * 1.55, Kit.C_CALL, false)  # 押した丸がぴったりなら ◇ の中に入る
			for p: Array in _judge["presses"]:
				_press_dot(Vector2(_ruler_x(float(int(p[0]) - TL.reply_start(jt)) / B.EIGHTH_TICKS), row), int(p[1]))
		var keep := tick < TL.reply_start(jt + 1) if jt + 1 < B.TURNS else (sec == TL.SONG and fresh)
		if keep:
			var a := 1.0 if fresh or sec == TL.REPLY else B.OLD_MARK_ALPHA
			var g: Array = _judge["grades"]
			for i in g.size():
				var at := Vector2(_ruler_x(int(_judge["pos"][i])), y + B.ROW_GRADE_DY)
				Kit.draw_grade(self, at, int(g[i]), 11.0, a)
				var lc := Kit.C_MISS if int(g[i]) == 3 else Kit.C_DIM
				draw_string(f, Vector2(at.x - 30, at.y + 36), S.KEYS[int(_judge["keys"][i])], HORIZONTAL_ALIGNMENT_CENTER, 60, 20, Color(lc, a))
	# 自分の曲: 今の小節で鳴った音(自分の音は青い丸、お手本は灰色の輪)
	if sec == TL.SONG or sec == TL.END:
		for d: Array in _song_dots:
			_press_dot(Vector2(_ruler_x(d[0]), row), d[1], d[2])
	# 回の進み: 8 つの回の結果(合った ●、外れ ×、まだ ○)。今の回(自分の曲では今の小節)を輪で囲む
	var cur := -1
	if sec == TL.CALL or sec == TL.REPLY:
		cur = judged
	elif sec == TL.SONG:
		@warning_ignore("integer_division")
		cur = (tick - B.SONG_START) / B.BAR_TICKS
	for i in B.TURNS:
		var at := Vector2(640 + (i - 3.5) * B.PIP_GAP, B.PIPS_Y)
		if i < _results.size():
			if _results[i]:
				draw_circle(at, 8, Kit.C_PERFECT)
			else:
				Kit.draw_grade(self, at, 3, 7.0)
		else:
			draw_arc(at, 7, 0, TAU, 24, Kit.C_RULER, 2.0, true)
		if i == cur:
			draw_arc(at, 13, 0, TAU, 32, _section_color(sec) if sec != TL.SONG else Kit.C_LAYER, 2.0, true)
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
