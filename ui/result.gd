# S3 結果(画面設計書 §4・§10)。見出し・点(600 ms で数え上がる)・最高との差・合った回(レコード 8 枚)・判定の 4 段と残機(FR-16)・共有する文字を出す。
# もう1回は 300 ms 後から押せる(Enter・R でも)。コピーは clipboard_set を試し、選べる枠も出す(E-14)。作りは KeyFlak の ui/result.gd。
# v0.3.0: 点が数え上がった後、合った回のレコードを 1 枚ずつ置く。新しい記録なら「自己最高」の判子と紙吹雪(点滅を弱めると紙吹雪は出さない)。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

const TALLY_Y := 256.0
const GRADE_Y := 304.0

var menu: Menu
var share := ""
var celebrate := false  # 新しい記録(判子と紙吹雪。テストが読む)
var rank := 0  # 段位(v0.3.1。Score.rank。テストが読む)
var _rank_at := Vector2(200, 128)
var _points := 0
var _turns_ok := 0
var _counts: Array = []
var _lives := 0
var _shown_at := 0
var _badge_at := Vector2(1060, 122)
var _points_label: Label
var _retry: Button
var _copied: Label


# result は sim.result()、rec は save_store.record() の戻り値。mode: 0 = 今日の曲、1 = 練習。
func build(mode: int, result: Dictionary, rec: Dictionary, share_text: String) -> void:
	size = Vector2(1280, 720)
	share = share_text
	_points = int(result["points"])
	_turns_ok = int(result["turns_ok"])
	_counts = result["counts"]
	_lives = int(result["lives"])
	celebrate = bool(rec["new_best"]) and _points > 0
	_shown_at = Time.get_ticks_msec()
	var head: String = S.RES_DONE % int(result["missed_turns"]) if result["finished"] else S.RES_STOP % int(result["reached"])
	add_child(Kit.place(Kit.label(head, 30, Kit.C_TEXT, 700, 6), 0, 16, 1280, 48))
	_points_label = Kit.big_label(S.RES_POINTS % "0", 100)
	add_child(Kit.place(_points_label, 0, 60, 1280, 132))
	if rec["prev_best"] != null:
		var best := int(rec["prev_best"]["score"])
		var text: String = S.RES_NEW_BEST % Score.comma(_points - best) if rec["new_best"] else S.RES_TO_BEST % Score.comma(best - _points)
		if mode == 0:
			text += S.RES_TODAY_BEST % Score.comma(maxi(best, _points))
		# 新しい記録は明るい生成り(緑は判定の「ぴったり」の色なので使わない。v0.3.0)
		add_child(Kit.place(Kit.label(text, 22, Kit.C_TEXT if rec["new_best"] else Kit.C_DIM, 700, 4), 0, 194, 1280, 34))
	var full := Kit.display().get_string_size(S.RES_POINTS % Score.comma(_points), HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	_badge_at = Vector2(minf(640 + full / 2 + 60, 1180), 96)  # 判子は点の字の右上に少し重ねる
	rank = Score.rank(_points)
	_rank_at = Vector2(maxf(640 - full / 2 - 100, 100), 128)  # 段位の看板は点の字の左(判子と反対の側)
	var turns := Kit.label(S.RES_TURNS % _turns_ok, 24, Kit.C_TEXT, 700, 4)
	turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(Kit.place(turns, 300, TALLY_Y - 20, 220, 40))
	# 判定の 4 段と残機: 印(形で分ける)と数を、字の幅に合わせて真ん中に並べる
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for g in 5:
		if g > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(26, 1)
			row.add_child(gap)
		var icon := Mark.new()
		icon.grade = g
		icon.filled = _lives > 0
		icon.custom_minimum_size = Vector2(24, 36)
		row.add_child(icon)
		var text: String = S.RES_GRADE % [S.GRADE_NAMES[g], int(_counts[g])] if g < 4 else S.RES_LIVES % _lives
		row.add_child(Kit.label(text, 22, Kit.C_TEXT if g < 4 else Kit.C_DIM, 500, 4))
	add_child(Kit.place(row, 0, GRADE_Y - 18, 1280, 36))
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 30), 490, 340, 300, 68)
	_retry.disabled = true
	add_child(_retry)
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	box.context_menu_enabled = true
	box.focus_mode = Control.FOCUS_CLICK
	box.add_theme_font_override("font", Kit.font(400))
	box.add_theme_font_size_override("font_size", 17)
	add_child(Kit.place(box, 290, 426, 700, 118))
	# 右クリックのメニューは、読むだけの枠で使う 2 つに絞って日本語にする(既定は英語の項目が並ぶ。v0.3.0)
	var cm := box.get_menu()
	cm.clear()
	cm.add_item(S.B_COPY, TextEdit.MENU_COPY)
	cm.add_item(S.MENU_SELECT_ALL, TextEdit.MENU_SELECT_ALL)
	var copy := Kit.place(Kit.button("copy", S.B_COPY, 24), 395, 558, 230, 56)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 24), 655, 558, 230, 56)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 18, Kit.C_DIM)
	add_child(Kit.place(_copied, 0, 622, 1280, 28))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 20, Kit.C_WARN), 0, 654, 1280, 36))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new([_retry, copy, title] as Array[Button], 0)



# 判定の印(0〜3)か残機のピック(4)を 1 つ描く。
class Mark extends Control:
	const Kit := preload("res://ui/kit.gd")
	var grade := 0
	var filled := true

	func _draw() -> void:
		if grade < 4:
			Kit.draw_grade(self, size / 2, grade, 10.0)
		else:
			Kit.draw_pick(self, size / 2, 10.0, Kit.C_DIM, filled)


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
	if t < _stamp_at() + B.CONFETTI_MS + 100:
		queue_redraw()


# 判子を押す時刻(画面に入ってから。点の数え上げと、レコードを置き終えた後)。
func _stamp_at() -> int:
	return B.COUNT_MS + B.TURNS * B.TALLY_STEP_MS


# 段位の看板(v0.3.1): 点が数え上がってから、点の左に吊り下がる。祝いではない(判子・紙吹雪・「記録」の言葉と重ねない)。
# 段は名前の字と、下の 5 つの電球の灯った数(形)で出す。色だけに頼らない。
func rank_rect() -> Rect2:
	return Rect2(_rank_at - Vector2(76, 66), Vector2(152, 114))  # 吊りひもまで


func badge_rect() -> Rect2:
	return Rect2(_badge_at - Vector2(88, 46), Vector2(176, 92))  # 傾けた判子を囲む


func rank_shown(t: int) -> bool:
	return t >= B.COUNT_MS


# 吊り下がりの進み 0〜1(動きを減らすと出た時から 1)。
func rank_k(t: int) -> float:
	if Kit.calm:
		return 1.0
	return clampf(float(t - B.COUNT_MS) / B.RANK_DROP_MS, 0.0, 1.0)


# 灯った電球の数(段 + 1 まで。動きを減らすと出た時から全部)。
@warning_ignore("integer_division")
func rank_lit(t: int) -> int:
	if Kit.calm:
		return rank + 1
	if t < B.COUNT_MS + B.RANK_DROP_MS:  # 割り算は 0 に向けて切り捨てるので、吊り下がりの間は先に外す
		return 0
	return clampi((t - B.COUNT_MS - B.RANK_DROP_MS) / B.RANK_BULB_MS + 1, 0, rank + 1)


func _draw_rank(t: int) -> void:
	if not rank_shown(t):
		return
	var k := rank_k(t)
	var e := 1.0 - k
	draw_set_transform(_rank_at + Vector2(0, -30.0 * e * e), 0.14 * sin(k * TAU) * e)
	var a := minf(1.0, k * 3.0 + 0.001) if not Kit.calm else 1.0
	for x: float in [-44.0, 44.0]:  # 吊りひもと鋲
		draw_line(Vector2(x, -48), Vector2(x * 0.7, -64), Color(Kit.C_EDGE, a), 2.0, true)
		draw_circle(Vector2(x * 0.7, -64), 3.0, Color(Kit.C_EDGE, a))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Kit.C_PANEL, a)
	sb.border_color = Color(Kit.C_TEXT, a)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(Kit.C_FLOOR, 0.6 * a)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(-76, -48, 152, 96))
	draw_rect(Rect2(-69, -41, 138, 82), Color(Kit.C_EDGE, a), false, 1.0)
	draw_string(Kit.font(700), Vector2(-76, -22), S.RANK_CAPTION, HORIZONTAL_ALIGNMENT_CENTER, 152, 14, Color(Kit.C_DIM, a))
	draw_string(Kit.font(800), Vector2(-76, 16), S.RANK_NAMES[rank], HORIZONTAL_ALIGNMENT_CENTER, 152, 30, Color(Kit.C_TEXT, a))
	var lit := rank_lit(t)
	for i in S.RANK_NAMES.size():
		var c := Vector2(-40 + i * 20, 30)
		if i < lit:
			draw_circle(c, 8.0, Color(Kit.C_SPOT, 0.18 * a))
			draw_circle(c, 4.5, Color(Kit.C_TEXT, a))
		else:
			draw_arc(c, 4.5, 0, TAU, 16, Color(Kit.C_EDGE, a), 1.5, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw() -> void:
	var t := Time.get_ticks_msec() - _shown_at
	_draw_rank(t)
	if Kit.calm:
		t = 100000  # 動きを減らす: 置き終えた形だけ
	# 合った回: 8 つの丸(プレイの「回の進み」と同じ形と色。合った数だけ緑で塗る)。点の数え上げの後に 1 つずつ跳ねて塗る
	for i in B.TURNS:
		var c := Vector2(556 + i * 46, TALLY_Y)
		var k := clampf(float(t - B.COUNT_MS - i * B.TALLY_STEP_MS) / B.TALLY_STEP_MS, 0.0, 1.0)
		draw_arc(c, 14, 0, TAU, 32, Kit.C_EDGE, 2.0, true)
		if i < _turns_ok and k > 0.0:
			draw_circle(c, 14.0 * (1.0 + 0.45 * (1.0 - k)), Color(Kit.C_PERFECT, k))
	if not celebrate:
		return
	# 紙吹雪(音符の頭とピック。決まった並び)
	var e := t - _stamp_at()
	if e >= 0 and e < B.CONFETTI_MS:
		var k := float(e) / B.CONFETTI_MS
		for i in 44:
			var h := fmod(i * 0.61803398, 1.0)
			var x := 140.0 + fmod(i * 233.7, 1000.0) + sin(k * 6.0 + i) * 30.0
			var y := -30.0 + k * (420.0 + 360.0 * h) + h * 120.0
			var col: Color = [Kit.C_CRIMSON, Kit.C_TEXT, Color("E0566B")][i % 3]
			col = Color(col, 1.0 - k * k)
			if i % 2 == 0:
				Kit.draw_pick(self, Vector2(x, y), 7.0, col)
			else:
				draw_circle(Vector2(x, y), 5.0, col)
	# 判子「自己最高」(点の右。押された時に大きい所から縮む)
	if t >= _stamp_at():
		var k := clampf(float(t - _stamp_at()) / 200.0, 0.0, 1.0)
		var sc := 1.0 + 0.6 * (1.0 - k)
		draw_set_transform(_badge_at, -0.2, Vector2(sc, sc))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Kit.C_CRIMSON, 0.9 * k)
		sb.border_color = Color(Kit.C_TEXT, k)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(-80, -28, 160, 56))
		draw_string(Kit.font(800), Vector2(-80, 10), S.RES_BADGE, HORIZONTAL_ALIGNMENT_CENTER, 160, 28, Color(Kit.C_TEXT, k))
		draw_set_transform_matrix(Transform2D.IDENTITY)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled:
		retry.emit()
		return
	menu.key(ev)
