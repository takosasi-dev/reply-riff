# S3 結果(画面設計書 §4)。見出し・点(600 ms で数え上がる)・最高との差・5 つの数・共有する文字を出す。
# もう1回は 300 ms 後から押せる(Enter・R でも)。コピーは clipboard_set を試し、選べる枠も出す(E-14)。作りは KeyFlak の ui/result.gd。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

var menu: Menu
var share := ""
var _points := 0
var _shown_at := 0
var _points_label: Label
var _retry: Button
var _copied: Label


# result は sim.result()、rec は save_store.record() の戻り値。mode: 0 = 今日の曲、1 = 練習。
func build(mode: int, result: Dictionary, rec: Dictionary, share_text: String) -> void:
	size = Vector2(1280, 720)
	share = share_text
	_points = int(result["points"])
	_shown_at = Time.get_ticks_msec()
	var head: String = S.RES_DONE % int(result["missed_turns"]) if result["finished"] else S.RES_STOP % int(result["reached"])
	add_child(Kit.place(Kit.label(head, 32, Kit.C_TEXT, 700), 0, 20, 1280, 48))
	_points_label = Kit.label(S.RES_POINTS % "0", 96, Kit.C_TEXT, 800)
	add_child(Kit.place(_points_label, 0, 68, 1280, 120))
	if rec["prev_best"] != null:
		var best := int(rec["prev_best"]["score"])
		var text: String = S.RES_NEW_BEST % Score.comma(_points - best) if rec["new_best"] else S.RES_TO_BEST % Score.comma(best - _points)
		if mode == 0:
			text += S.RES_TODAY_BEST % Score.comma(maxi(best, _points))
		add_child(Kit.place(Kit.label(text, 24, Kit.C_PERFECT if rec["new_best"] else Kit.C_DIM, 700), 0, 190, 1280, 36))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	row.add_child(Kit.label(S.RES_TURNS % int(result["turns_ok"]), 26, Kit.C_TEXT, 500))
	for g in 4:
		row.add_child(Kit.label(S.RES_GRADE % [S.GRADE_NAMES[g], int(result["counts"][g])], 26, Kit.C_TEXT, 500))
	add_child(Kit.place(row, 0, 240, 1280, 44))
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 30), 490, 306, 300, 68)
	_retry.disabled = true
	add_child(_retry)
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	box.context_menu_enabled = true
	box.focus_mode = Control.FOCUS_CLICK
	box.add_theme_font_override("font", Kit.font(400))
	box.add_theme_font_size_override("font_size", 18)
	box.add_theme_color_override("font_readonly_color", Kit.C_TEXT)
	add_child(Kit.place(box, 290, 398, 700, 100))
	var copy := Kit.place(Kit.button("copy", S.B_COPY, 24), 420, 514, 200, 56)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 24), 660, 514, 200, 56)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 18, Kit.C_DIM)
	add_child(Kit.place(_copied, 0, 578, 1280, 28))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 20, Kit.C_WARN), 0, 630, 1280, 40))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new([_retry, copy, title] as Array[Button], 0)


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


@warning_ignore("integer_division")
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() - _shown_at
	var shown := _points if t >= B.COUNT_MS else _points * t / B.COUNT_MS
	_points_label.text = S.RES_POINTS % Score.comma(shown)
	if _retry.disabled and t >= B.RETRY_LOCK_MS:
		_retry.disabled = false


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled:
		retry.emit()
		return
	menu.key(ev)
