# 画面の切り替え(S0〜S5)・入力の振り分け・保存・自動の一時停止を受け持つ。ゲームの決まりは持たない(INV-1)。作りは KeyFlak の ui/main.gd。
# ?keys=1(または --keys)でキーの確かめの画面(共通 §3 の 22)。--auto(公開版では効かない)で S0 → 今日の曲(正解 bot・途中で一時停止
# → 設定 → 続ける・自分の曲を Enter で飛ばす)→ 結果 → もう1回(何もしない bot で残機 0)→ 結果 を自動で通して終わる(ヘッドレスの smoke。--music を足すと曲の位置で進める)。
extends Node

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const TL := preload("res://core/timeline.gd")
const Sim := preload("res://core/sim.gd")
const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Bots := preload("res://core/bots.gd")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Play := preload("res://ui/play.gd")
const Title := preload("res://ui/title.gd")
const Result := preload("res://ui/result.gd")
const Settings := preload("res://ui/settings.gd")
const Pause := preload("res://ui/pause.gd")


# 背景(上から下へ 2 色の帯)。
class Bg extends Control:
	func _draw() -> void:
		Kit.draw_bg(self)


var stage: Control
var store: Store
var screen := "gate"  # gate / title / play / result / settings / keys
var current: Control = null  # 今の画面(play の時は play)
var play: Play = null
var pause_view: Pause = null
var settings_from := "title"
var run := {}  # 今の回 { mode, seed, day, date }
var title_sel := 0  # タイトルで最後に選んだボタン(戻った時にそのまま選んでおく)
var auto := false
var music_clock := false
var _touch_note: Label = null
var _keys_label: Label = null
var _key_log: Array = []
var _esc_count := 0
var _visibility_cb: Variant = null
var _auto_results := 0
var _auto_step := 0
var _settings_overlay: Control = null
var debug := false  # ?debug=1: window.rrState に状態を出す(Web の自動の確かめが読むだけ)
var frame_ms: Array = []
var clock_log: Array = []  # ?debug=1 の時だけ: [曲の位置(秒), ブラウザの AudioContext の時刻(秒)](R-4 の目安)
var _last_frame := 0
var _dbg_n := 0


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	add_child(stage)
	stage.add_child(Bg.new())
	get_viewport().size_changed.connect(_layout)
	_layout()
	store = Store.new()
	_apply_settings()
	auto = _flag("auto") and not OS.has_feature("web")  # 公開版では効かせない(bot の点を保存しない)
	music_clock = auto and _flag("music")  # --music なら曲の位置で進める(実時間。1 曲 60 秒)
	if auto and not music_clock:
		Engine.time_scale = 4.0  # 1 フレーム 8 tick で進める
	debug = _flag("debug")
	RenderingServer.frame_post_draw.connect(_after_draw)
	_watch_visibility()
	_show_gate()


# 縦横比が 16:9 でない窓では、表示の範囲が広がる(project.godot の aspect=expand)。舞台をその真ん中に置く。
func _layout() -> void:
	stage.position = ((get_viewport().get_visible_rect().size - stage.size) / 2.0).floor()


static func _flag(flag: String) -> bool:
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("location.search", true)
		return q is String and q.contains(flag + "=1")
	return OS.get_cmdline_user_args().has("--" + flag)


func _apply_settings() -> void:
	Notes.set_volume(int(store.settings()["volume"]))


func _clear() -> void:
	Music.stop()
	if pause_view != null:
		pause_view.queue_free()
		pause_view = null
	for c in stage.get_children():
		if c is Bg:
			continue
		c.queue_free()
	current = null
	play = null


# --- S0 始める ---

func _show_gate() -> void:
	_clear()
	screen = "gate"
	var g := Control.new()
	g.size = Vector2(1280, 720)
	g.add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 220, 1280, 100))
	g.add_child(Kit.place(Kit.label(S.S0_START, 28, Kit.C_TEXT, 500), 0, 360, 1280, 44))
	g.add_child(Kit.place(Kit.label(S.S0_KEYBOARD, 18, Kit.C_DIM), 0, 410, 1280, 30))
	_touch_note = Kit.label(S.TOUCH, 22, Kit.C_WARN, 700)
	_touch_note.visible = false
	g.add_child(Kit.place(_touch_note, 0, 470, 1280, 40))
	stage.add_child(g)
	current = g


func _input(event: InputEvent) -> void:
	if screen == "gate":
		if event is InputEventScreenTouch and event.pressed:
			_touch_note.visible = true  # FR-26: タッチで開いた人に伝える
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
			return  # タッチから作られたマウスのイベント
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			Notes.unlock()  # FR-23: この入力で音を出せるようにする。操作には数えない
			get_viewport().set_input_as_handled()
			if _flag("keys"):
				_show_keys()
			else:
				_show_title()
		return
	if not (event is InputEventKey):
		return
	if screen != "play" and (event.ctrl_pressed or event.meta_pressed or event.alt_pressed):
		return  # 結果の枠の Ctrl+C などは部品に渡す(FR-24: ゲームの操作には数えない)
	get_viewport().set_input_as_handled()  # 矢印・Space を Godot のフォーカスの移動に使わせない
	if screen == "keys":
		_keys_input(event)
	elif screen == "settings":
		current.key(event)
	elif pause_view != null:
		pause_view.key(event)
	elif current != null and current.has_method("key"):
		current.key(event)


# --- S1 タイトル ---

func _show_title() -> void:
	_clear()
	screen = "title"
	var d := _today()
	var t := Title.new()
	t.build(store, d["day"], d["date"], title_sel)
	t.chosen.connect(_on_title)
	stage.add_child(t)
	current = t


func _on_title(what: String) -> void:
	var d := _today()
	title_sel = ["daily", "practice", "settings"].find(what)
	match what:
		"settings":
			_show_settings("title")
		"daily":
			_start({"mode": Sim.MODE_DAILY, "seed": Day.day_seed(d["day"]), "day": d["day"], "date": d["date"]})
		"practice":
			_start({"mode": Sim.MODE_PRACTICE, "seed": _practice_seed(), "day": d["day"], "date": d["date"]})


static func _practice_seed() -> int:
	var s := Time.get_ticks_usec() & 0xFFFFFFFF  # FR-1
	return s if s != 0 else 1


# 端末の今日の日付。始めた時の日付で曲を決める(E-15)。
func _today() -> Dictionary:
	var t := Time.get_date_dict_from_system()
	var y := int(t["year"])
	var m := int(t["month"])
	var dd := int(t["day"])
	return {"day": Day.day_index(y, m, dd), "date": Day.date_string(y, m, dd)}


# --- S2 プレイ ---

func _start(r: Dictionary) -> void:
	_clear()
	run = r
	clock_log.clear()
	screen = "play"
	play = Play.new()
	var st: Dictionary = store.settings()
	play.shake_on = st["shake"]
	play.reduce_flash = st["reduce_flash"]
	play.frame_clock = auto and not music_clock
	stage.add_child(play)
	play.start(int(r["mode"]), int(r["seed"]))
	if auto:
		play.bot = Bots.new(Bots.EXACT if _auto_results == 0 else Bots.IDLE)
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_pause)
	current = play


# もう1回・やり直す(FR-17)。今日の曲は同じ種、練習は毎回ちがうフレーズ(種を引き直す)。
func _again() -> void:
	if int(run["mode"]) == Sim.MODE_PRACTICE:
		run["seed"] = _practice_seed()
	_start(run)


func _pause() -> void:
	if play == null or pause_view != null or not play.is_playing():
		return
	play.paused = true
	play.cancel_input()
	play.pause_music()
	pause_view = Pause.new()
	pause_view.build()
	pause_view.picked.connect(_on_pause)
	stage.add_child(pause_view)


func _on_pause(what: String) -> void:
	match what:
		"resume":
			pause_view.queue_free()
			pause_view = null
			play.resume()  # 今の回のお手本の 1 小節前から(D-13)
		"restart":
			_again()
		"settings":
			_show_settings("pause")
		"title":
			_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focus_lost()


# フォーカスが外れた・タブが裏に回った(E-9)。押されている組を空にし、プレイ中なら一時停止。戻っても自動では再開しない。
func _focus_lost() -> void:
	if play != null:
		play.cancel_input()
	if screen == "title" and current != null:
		current.release_all()
	_pause()


# タブが裏に回ったら一時停止にする。Web では通知が来ないことがあるので、ブラウザにも聞く(ParryDuel と同じ)。
func _watch_visibility() -> void:
	if not OS.has_feature("web"):
		return
	_visibility_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void: _focus_lost())
	var doc: Variant = JavaScriptBridge.get_interface("document")
	if doc != null:
		doc.addEventListener("visibilitychange", _visibility_cb)


# --- S3 結果 ---

func _on_finished(result: Dictionary) -> void:
	var r := run
	var rec := store.record(int(r["mode"]), int(r["day"]), result)
	var text := Share.make(r["date"], int(r["mode"]), rec["first_today"], result)
	_clear()
	screen = "result"
	var v := Result.new()
	v.build(int(r["mode"]), result, rec, text)
	v.retry.connect(_again)
	v.to_title.connect(_show_title)
	stage.add_child(v)
	current = v
	if auto:
		_auto_results += 1
		print("SMOKE result %d: %s" % [_auto_results, JSON.stringify(result)])
		print(text)


# --- S4 設定 ---

func _show_settings(from: String) -> void:
	settings_from = from
	var s := Settings.new()
	s.build(store)
	s.back.connect(_settings_back.bind(s))
	if from == "pause":
		pause_view.visible = false
		var dim := ColorRect.new()
		dim.color = Color(Kit.C_BG, 0.96)
		s.add_child(Kit.place(dim, -2000, -2000, 5280, 4720))  # 余りまで覆う(aspect=expand)
		s.move_child(dim, 0)
		stage.add_child(s)
		current = s
		screen = "settings"
		pause_view.process_mode = Node.PROCESS_MODE_DISABLED
		_settings_overlay = s
	else:
		_clear()
		screen = "settings"
		stage.add_child(s)
		current = s


func _settings_back(s: Control) -> void:
	_apply_settings()
	if settings_from == "pause" and play != null:
		var st: Dictionary = store.settings()
		play.shake_on = st["shake"]
		play.reduce_flash = st["reduce_flash"]
		s.queue_free()
		_settings_overlay = null
		pause_view.visible = true
		pause_view.process_mode = Node.PROCESS_MODE_INHERIT
		current = play
		screen = "play"
	else:
		_show_title()


# --- キーの確かめ(共通 §3 の 22。?keys=1 の時だけ) ---

func _show_keys() -> void:
	_clear()
	screen = "keys"
	var g := Control.new()
	g.size = Vector2(1280, 720)
	g.add_child(Kit.place(Kit.label(S.KEYS_TITLE, 22, Kit.C_TEXT, 700), 0, 20, 1280, 40))
	_keys_label = Kit.label("", 16, Kit.C_TEXT, 400)
	_keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_keys_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	g.add_child(Kit.place(_keys_label, 40, 80, 1200, 620))
	stage.add_child(g)
	current = g


func _keys_input(ev: InputEventKey) -> void:
	_key_log.append(S.KEY_DETAIL % [ev.physical_keycode, OS.get_keycode_string(ev.physical_keycode), OS.get_keycode_string(ev.key_label), ev.unicode,
		ev.pressed, ev.echo, ev.ctrl_pressed, ev.alt_pressed, ev.meta_pressed, ev.shift_pressed])
	_key_log = _key_log.slice(maxi(_key_log.size() - 24, 0))
	_keys_label.text = "\n".join(_key_log)
	if ev.pressed and not ev.echo:
		_esc_count = _esc_count + 1 if ev.physical_keycode == KEY_ESCAPE else 0
		if _esc_count >= 2:
			_show_title()


# --- 自動の確かめ(smoke) ---

func _process(_delta: float) -> void:
	if not auto:
		return
	match screen:
		"gate":
			print("SMOKE gate")
			_input(_key(KEY_X))
		"title":
			print("SMOKE title")
			_input(_key(KEY_ENTER))  # 今日の曲
		"settings":
			print("SMOKE settings")
			_input(_key(KEY_ESCAPE))
		"play":
			var sec := TL.section(play.sim.tick)
			if _auto_step == 0 and play.sim.tick > TL.reply_start(2) + 100 and pause_view == null:
				_auto_step = 1
				print("SMOKE pause at %d" % play.sim.tick)
				_input(_key(KEY_ESCAPE))
				_input(_key(KEY_DOWN))
				_input(_key(KEY_DOWN))
				_input(_key(KEY_ENTER))  # 設定
			elif _auto_step == 1 and pause_view != null and screen == "play":
				_auto_step = 2
				_input(_key(KEY_ESCAPE))  # 続ける
				print("SMOKE resume at %d" % play.sim.tick)
			elif _auto_step == 2 and sec == TL.SONG and play.sim.tick > B.SONG_START + 600:
				_auto_step = 3
				print("SMOKE skip at %d" % play.sim.tick)
				_input(_key(KEY_ENTER))
		"result":
			if not current._retry.disabled:
				if _auto_results >= 2:
					print("SMOKE done")
					auto = false
					get_tree().quit(0)
				else:
					_input(_key(KEY_ENTER))  # もう1回


static func _key(pk: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	return e


# --- デバッグ用の窓口(?debug=1 の時だけ。読むだけ。作りは KeySwat) ---

func _after_draw() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0 and frame_ms.size() < 20000:
		frame_ms.append((now - _last_frame) / 1000.0)
	_last_frame = now
	if not (debug and OS.has_feature("web")):
		return
	Music.probe_ctx = true
	if Music.last_pair.size() == 2 and (clock_log.is_empty() or clock_log[-1][0] != Music.last_pair[0]) and clock_log.size() < 20000:
		clock_log.append(Music.last_pair.duplicate())
	JavaScriptBridge.eval("window.rrState=" + JSON.stringify(JSON.stringify(state())), true)
	_dbg_n += 1
	if _dbg_n % 60 == 0:
		JavaScriptBridge.eval("window.rrClock=" + JSON.stringify(JSON.stringify(clock_log)), true)


func state() -> Dictionary:
	var out := {"screen": screen, "paused": pause_view != null, "buttons": {}, "notes": Notes.played, "last_key": Notes.last_key,
		"unlocked": Notes.unlocked, "save_failed": store.write_failed, "load_failed": store.load_failed,
		"music": {"layers": Music.layers, "loops": Music.loops, "playing": Music.is_running(), "latency": AudioServer.get_output_latency()},
		"frames": frame_ms.size()}
	if current != null and "menu" in current and current.menu != null:
		out["sel"] = current.menu.sel
	var root: Control = _settings_overlay if _settings_overlay != null else (pause_view if pause_view != null and pause_view.visible else current)
	if root != null:
		for b in root.find_children("*", "Button", true, false):
			var btn := b as Button
			if btn.is_visible_in_tree() and not btn.disabled:
				var c := btn.global_position - stage.global_position + btn.size / 2  # 舞台の座標(1280×720)
				out["buttons"][String(btn.name)] = [c.x, c.y]
	if play != null and play.sim != null:
		var sn: Dictionary = play.sim.snapshot()
		sn["pos"] = [play.position.x, play.position.y]
		sn["held"] = play.held.keys()
		sn["phrase"] = play.sim.phrase  # 窓なし Chrome の bot が弾き返すため(?debug=1 の時だけ)
		out["play"] = sn
	if screen == "result" and current is Result:
		out["share"] = (current as Result).share
	return out

