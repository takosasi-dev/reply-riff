# S1 タイトル(画面設計書 §2)。入口 2 つ(今日の曲・練習)と設定、今日の記録と練習の最高。
# 下に鍵盤の帯を薄く出し、8 キーを押すと鳴る(試し弾き。↑↓・Enter のメニュー操作とは別)。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const Menu := preload("res://ui/menu.gd")

const STRIP_Y := 540.0
const STRIP_SCALE := 0.62

var menu: Menu
var held := {}  # 試し弾きで押されている鍵


# store は save_store、day は通し日数、date は "2026-11-19"。
# sel は選んでおくボタン(0 今日の曲・1 練習・2 設定。設定やプレイから戻った時に、前に選んだ物のまま)。
func build(store: RefCounted, day: int, date: String, sel: int = 0) -> void:
	size = Vector2(1280, 720)
	add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 30, 1280, 100))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_DIM, 500), 0, 128, 1280, 44))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 18, Kit.C_WARN), 0, 172, 1280, 28))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 30), 300, 210, 520, 88)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 26), 300, 312, 520, 88)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 300, 414, 240, 72)
	for b: Button in [daily, practice, settings]:
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
	var d: Dictionary = store.daily(day)
	if d["first"] != null:
		_note((S.REC_FIRST % Score.comma(d["first"]["score"])) + " / " + (S.REC_TODAY_BEST % Score.comma(d["best"]["score"])), daily)
	elif store.practice_best() != null or store.data["daily"] != null:
		_note(S.REC_NONE, daily)  # 初めての起動は記録の行を出さない
	var pb: Variant = store.practice_best()
	if pb != null:
		_note(S.REC_BEST % Score.comma(pb["score"]), practice)
	var sound := Kit.label(S.SOUND_NOTE, 18, Kit.C_DIM)
	sound.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(sound, 24, 676, 600, 32))  # E-11
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(Kit.place(ver, 1056, 676, 200, 32))
	menu = Menu.new([daily, practice, settings] as Array[Button], sel)


func _note(text: String, by: Button) -> void:
	var l := Kit.label(text, 18, Kit.C_DIM, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, by.position.x + by.size.x + 24, by.position.y, 440, by.size.y))


func _draw() -> void:
	for k in B.KEYS_N:
		Kit.draw_key(self, k, Kit.key_rect(k, STRIP_Y, STRIP_SCALE), 1.0 if held.has(k) else 0.0, 1.0 if held.has(k) else 0.0, false, 1.0, 1.0 if held.has(k) else 0.5)


func key(ev: InputEventKey) -> void:
	var i := Keymap.index_of(ev)
	if i >= 0:
		if not ev.pressed:
			held.erase(i)
		elif not ev.echo and not Keymap.has_modifier(ev):
			held[i] = true
			Notes.play_key(i)
		queue_redraw()
		return
	menu.key(ev)


func release_all() -> void:
	held.clear()
	queue_redraw()
