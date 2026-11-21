# 画面の共通部品(色・字体・ラベル・ボタン・置き場所)と、背景・題字・鍵・判定の印の絵。画面設計書 §8〜§10 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。ボタン・枠の見た目は ui/theme.tres(tools/make_theme.gd が作る)。
# v0.3.0: 題材は小さなライブハウス(暖かい壁・上からのスポット・レコードと譜面)。意味の色(黄 = お手本、青 = 自分、判定の 4 段、紫 = 層)は変えない。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"
const DISPLAY := "res://assets/fonts/Shrikhand-Subset.ttf"  # 題字と数字(SIL OFL)

# 地と飾り(画面設計書 §10)。飾りに黄と青は使わない
const C_BG := Color("1B1218")  # 壁(上)
const C_BG2 := Color("2B1A23")  # 壁(下)
const C_PANEL := Color("33222B")
const C_EDGE := Color("6B5260")
const C_FLOOR := Color("120C10")
const C_CRIMSON := Color("C8384E")  # 幕の深紅(飾りだけ。意味は持たせない)
const C_SPOT := Color("FFF1DC")  # スポットの光(薄く使う)
const C_KEY_EDGE := Color("A0898F")
const C_KEY_FILL := Color("2C1E26")
const C_RULER := Color("5E4753")
# 意味の色(画面設計書 §8・§9)
const C_PRESS := Color("6BB8FF")
const C_HINT := Color("FFE066")
const C_NOW := Color("F4E9DA")
const C_CALL := Color("FFE066")
const C_PERFECT := Color("7EE787")
const C_GOOD := Color("6BB8FF")
const C_OK := Color("B5A397")
const C_MISS := Color("FF6B6B")
const C_LAYER := Color("C792EA")
const C_TEXT := Color("F4E9DA")
const C_DIM := Color("B5A397")
const C_WARN := Color("FFB84D")

const BPM_SEC := 0.6  # 1 拍(100 BPM)。タイトルの飾りの拍

# 点滅を弱める(= 動きも減らす。画面設計書 §10)。main が設定から入れる
static var calm := false
static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


# 題字・数字の字体。日本語(「点」など)は Noto Sans JP の太字に落とす。
static func display() -> Font:
	if not _fonts.has("display"):
		var fv := FontVariation.new()
		fv.base_font = load(DISPLAY)
		fv.fallbacks = [font(800)]
		_fonts["display"] = fv
	return _fonts["display"]


static func is_calm() -> bool:
	return calm


# outline は縁取りの太さ(どんな背景の上でも読めるように。HUD と大きな字)。
static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", C_FLOOR)
	return l


# 題字の字体の大きな字(点・数え)。縁取りと深紅の影。
static func big_label(text: String, size: int, color: Color = C_TEXT) -> Label:
	var l := label(text, size, color, 800, maxi(6, int(size * 0.1)))
	l.add_theme_font_override("font", display())
	l.add_theme_color_override("font_shadow_color", Color(C_CRIMSON, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


# ボタン。node_name は自動の確認が押す時の目印。見た目は Theme(ui/theme.tres)、キーボードでの選択は set_selected。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # 矢印を Godot のフォーカスの移動に使わせない(選んでいる印は ui/menu.gd が付ける)
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	return b


# 選んでいるボタン: Theme の SelButton(生成りの縁・深紅の光)と、左に回るレコードの印。
static func set_selected(b: Button, on: bool) -> void:
	b.theme_type_variation = &"SelButton" if on else &""
	var d: Control = b.get_node_or_null("SelDisc")
	if on and d == null:
		d = Disc.new()
		d.name = "SelDisc"
		b.add_child(d)
	elif not on and d != null:
		b.remove_child(d)
		d.queue_free()
	if on:
		var h := b.size.y if b.size.y > 0 else 68.0
		var r := minf(15.0, h * 0.24)
		d.position = Vector2(16.0 + r, h / 2)
		d.set("r", r)


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
		if c.has_node("SelDisc"):
			set_selected(c, true)  # 大きさが決まったので印を置き直す
	return c


# 選んでいる印のレコード(半径 r)。点滅を弱めると回らない。
class Disc extends Control:
	const Kit := preload("res://ui/kit.gd")
	var r := 14.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if not Kit.is_calm():
			queue_redraw()

	func _draw() -> void:
		var a := 0.0 if Kit.is_calm() else Time.get_ticks_msec() / 1000.0 * TAU * 0.55
		Kit.draw_record(self, Vector2.ZERO, r, a)


# レコード 1 枚(中心 c、半径 r、回り a)。題字・選んだ印・結果の合った回で使う。
static func draw_record(ci: CanvasItem, c: Vector2, r: float, a: float, alpha: float = 1.0) -> void:
	ci.draw_circle(c, r, Color(C_FLOOR, alpha))
	ci.draw_arc(c, r, 0, TAU, 40, Color(C_EDGE, alpha), 1.5, true)
	for k in 3:
		ci.draw_arc(c, r * (0.55 + 0.14 * k), 0, TAU, 32, Color(C_EDGE, 0.55 * alpha), maxf(1.0, r / 14.0), true)
	ci.draw_arc(c, r * 0.8, a, a + 0.9, 12, Color(C_SPOT, 0.35 * alpha), maxf(1.5, r / 9.0), true)  # 光の筋(回りが見える)
	ci.draw_circle(c, r * 0.34, Color(C_CRIMSON, alpha))
	ci.draw_circle(c, maxf(1.0, r * 0.07), Color(C_SPOT, alpha))


# 題字: 譜面の 5 本線の上に「Reply」(生成り)と「Riff」(深紅に生成りの縁)、左に回るレコード、線の上に揺れる 8 分音符。
class Logo extends Control:
	const Kit := preload("res://ui/kit.gd")
	var font_size := 104

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if not Kit.is_calm():
			queue_redraw()

	func _draw() -> void:
		var t := 0.0 if Kit.is_calm() else Time.get_ticks_msec() / 1000.0
		var f := Kit.display()
		var fs := font_size
		var w1 := f.get_string_size("Reply", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w2 := f.get_string_size("Riff", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var rr := fs * 0.6  # レコードの半径
		var total := rr * 2 + fs * 0.25 + w1 + w2
		var x0 := (size.x - total) / 2
		var mid := size.y / 2
		# 譜面(5 本線)
		var gap := fs * 0.13
		for k in 5:
			var y := mid - 2 * gap + k * gap
			draw_line(Vector2(x0 - 40, y), Vector2(x0 + total + 60, y), Color(Kit.C_SPOT, 0.16), 2.0)
		# 拍で揺れる 8 分音符(線の上)
		var beat := fmod(t / Kit.BPM_SEC, 1.0)
		var bob := 0.0 if Kit.is_calm() else -7.0 * pow(1.0 - beat, 3)
		_note(Vector2(x0 + total + 26, mid + gap + bob), fs * 0.11)
		# レコード
		Kit.draw_record(self, Vector2(x0 + rr, mid), rr, t * TAU * 0.3)
		# 字(影 → 本体)
		var base := mid + fs * 0.33
		var x := x0 + rr * 2 + fs * 0.25
		draw_string(f, Vector2(x + 6, base + 7), "Reply", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Kit.C_FLOOR, 0.9))
		draw_string(f, Vector2(x + w1 + 6, base + 7), "Riff", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Kit.C_FLOOR, 0.9))
		draw_string(f, Vector2(x, base), "Reply", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Kit.C_TEXT)
		draw_string_outline(f, Vector2(x + w1, base), "Riff", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Kit.C_TEXT)
		draw_string(f, Vector2(x + w1, base), "Riff", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Kit.C_CRIMSON)

	func _note(at: Vector2, s: float) -> void:
		var c := Color(Kit.C_SPOT, 0.75)
		draw_set_transform(at, -0.35, Vector2(1.3, 1.0))
		draw_circle(Vector2.ZERO, s, c)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var top := at + Vector2(s * 1.15, -s * 5.5)
		draw_line(at + Vector2(s * 1.15, 0), top, c, maxf(2.0, s * 0.28))
		draw_line(top, top + Vector2(s * 1.6, s * 2.2), c, maxf(2.0, s * 0.32))


# 背景: 壁の 2 色・床・両端の幕・上の 2 つのスポット(拍で揺れる)・光の中の埃。舞台(1280×720)の外まで描く(aspect=expand の余り)。
# beat は拍の位置(小数。整数の所が拍の頭)、lively はタイトル 1・結果など 0.8・プレイ 0.6。
# プレイ(lively < 0.7)では、画面を広く覆う半透明の光と幕を描かない(窓なし Chrome の計測で重さが 3 割増えたため。埃と壁だけ)。
# left・right は見えている範囲の左右の端(舞台の座標)。幕はそこに下げる。
static func draw_bg(ci: CanvasItem, beat: float = 0.0, lively: float = 1.0, left: float = 0.0, right: float = 1280.0) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(-2000, -2000), Vector2(3280, -2000), Vector2(3280, 640), Vector2(-2000, 640)]),
		PackedColorArray([C_BG, C_BG, C_BG2, C_BG2]))
	ci.draw_polygon(PackedVector2Array([Vector2(-2000, 640), Vector2(3280, 640), Vector2(3280, 2720), Vector2(-2000, 2720)]),
		PackedColorArray([Color("24161E"), Color("24161E"), C_FLOOR, C_FLOOR]))
	ci.draw_line(Vector2(-2000, 640), Vector2(3280, 640), Color(C_SPOT, 0.07), 2.0)
	var t := 0.0 if calm else Time.get_ticks_msec() / 1000.0
	if lively < 0.7:
		_dust(ci, t, lively)
		return
	_drapes(ci, left, right)
	var frac := fmod(beat, 1.0)
	var pulse := 0.0 if calm else 0.02 * pow(1.0 - frac, 2)
	var sway := 0.0 if calm else sin(beat / 8.0 * TAU) * 46.0  # 2 小節で 1 往復
	for side in 2:
		var sx := 250.0 if side == 0 else 1030.0
		var tx := (560.0 + sway) if side == 0 else (720.0 - sway)
		var a := (0.075 + pulse) * lively
		# 灯りは舞台のずっと上(縦に長い窓の余りでも、光の筋が途中で切れない)
		var top_l := Vector2(sx - 30, -1400)
		var top_r := Vector2(sx + 30, -1400)
		var bot_l := Vector2(tx - 250, 660)
		var bot_r := Vector2(tx + 250, 660)
		var k := (1400.0 - 40.0) / 2060.0  # 舞台の上の端あたりまでは同じ明るさ、そこから下へ消える
		var mid_l := top_l.lerp(bot_l, k)
		var mid_r := top_r.lerp(bot_r, k)
		ci.draw_colored_polygon(PackedVector2Array([top_l, top_r, mid_r, mid_l]), Color(C_SPOT, a))
		ci.draw_polygon(PackedVector2Array([mid_l, mid_r, bot_r, bot_l]),
			PackedColorArray([Color(C_SPOT, a), Color(C_SPOT, a), Color(C_SPOT, 0.0), Color(C_SPOT, 0.0)]))
		ci.draw_set_transform(Vector2(tx, 660), 0.0, Vector2(1.0, 0.16))
		ci.draw_circle(Vector2.ZERO, 260.0, Color(C_SPOT, 0.035 * lively))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	_dust(ci, t, lively)


# 埃(決まった並び。時間で上へ流れる)。
static func _dust(ci: CanvasItem, t: float, lively: float) -> void:
	for i in 36:
		var h := fmod(i * 0.61803398, 1.0)
		var x := fmod(i * 197.3 + sin(t * 0.3 + i) * 12.0, 1280.0)
		var y := 640.0 - fmod(t * (8.0 + 10.0 * h) + i * 71.0, 700.0)
		ci.draw_circle(Vector2(x, y), 1.2 + h * 1.3, Color(C_SPOT, (0.08 + 0.14 * h) * lively))


# 見えている範囲の両端に下げた深紅の幕(縦のひだ)。床の線(y 640)まで。
static func _drapes(ci: CanvasItem, left: float, right: float) -> void:
	var w := 96.0
	for side in 2:
		var x0 := left if side == 0 else right - w
		for k in 6:
			var fx := x0 + k * w / 6
			var lit := Color("5A1A2A") if k % 2 == (0 if side == 0 else 1) else Color("3E1220")
			ci.draw_polygon(PackedVector2Array([Vector2(fx, -2000), Vector2(fx + w / 6, -2000), Vector2(fx + w / 6, 640), Vector2(fx, 640)]),
				PackedColorArray([lit, lit, lit.darkened(0.45), lit.darkened(0.45)]))
		var edge := x0 + w if side == 0 else x0
		ci.draw_line(Vector2(edge, -2000), Vector2(edge, 640), Color(C_FLOOR, 0.8), 3.0)


# 背景を描く Control。拍は壁の時計の 100 BPM(飾りだけ。曲と判定の時計には触らない)。
class Backdrop extends Control:
	const Kit := preload("res://ui/kit.gd")
	var lively := 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if not Kit.is_calm() and lively >= 0.7:  # プレイの間は描き直さない(止まった埃と壁だけ。フレームを軽くする)
			queue_redraw()

	func _draw() -> void:
		var origin := get_global_transform().origin  # 舞台の左上(窓の中の位置)
		var vis := get_viewport_rect().size
		Kit.draw_bg(self, Time.get_ticks_msec() / 1000.0 / Kit.BPM_SEC, lively, -origin.x, vis.x - origin.x)


# 画面の切り替わり(画面設計書 §10)。前の画面を暗くし(out_ms)、新しい画面をスポットの輪で開く(in_ms)。
# 見た目だけ: 画面の入れ替えと入力はすぐに済んでいる。点滅を弱めると、暗い幕が 150 ms で消えるだけ。
class Curtain extends Control:
	const Kit := preload("res://ui/kit.gd")
	const CALM_MS := 150
	var _at := -100000
	var _out := 0
	var _in := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func start(out_ms: int, in_ms: int) -> void:
		_at = Time.get_ticks_msec()
		_out = 0 if Kit.is_calm() else out_ms
		_in = CALM_MS if Kit.is_calm() else in_ms
		queue_redraw()

	# 動いている間か(テストが読む)。
	func active() -> bool:
		return Time.get_ticks_msec() - _at < _out + _in

	# 暗くし終えたか(前の画面を消してよいか)。
	func covered() -> bool:
		return Time.get_ticks_msec() - _at >= _out

	func _process(_d: float) -> void:
		if Time.get_ticks_msec() - _at < _out + _in + 100:
			queue_redraw()

	func _draw() -> void:
		var e := Time.get_ticks_msec() - _at
		if e >= _out + _in:
			return
		var full := Rect2(-4000, -4000, 9000, 9000)
		if e < _out:
			draw_rect(full, Color(Kit.C_FLOOR, float(e) / _out))
			return
		var k := float(e - _out) / _in
		if Kit.is_calm():
			draw_rect(full, Color(Kit.C_FLOOR, 1.0 - k))
			return
		var eo := 1.0 - pow(1.0 - k, 3)
		var c := size / 2
		var reach := size.length() * 0.6 + 40
		var r := reach * eo
		_ring(c, r, reach + 3000, Kit.C_FLOOR)
		draw_arc(c, r, 0, TAU, 96, Color(Kit.C_SPOT, 0.25 * (1.0 - k)), 6.0, true)

	func _ring(c: Vector2, r0: float, r1: float, col: Color) -> void:
		var n := 64
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			draw_colored_polygon(PackedVector2Array([c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1]), col)


# 鍵 k の左上。4 つずつ左右に分け、間を 96 空ける(画面設計書 §3)。
static func key_rect(k: int, y: float = B.KEY_Y, scale: float = 1.0) -> Rect2:
	var w := B.KEY_W * scale
	var gap := B.KEY_GAP * scale
	var hand := 4 * w + 3 * gap
	var x0 := (1280.0 - 2 * hand - B.HAND_GAP * scale) / 2
	var x := x0 + (k % 4) * (w + gap) + (0.0 if k < 4 else hand + B.HAND_GAP * scale)
	return Rect2(x, y, w, B.KEY_H * scale)


static var _box: StyleBoxFlat = null


# 描く時だけ使う StyleBoxFlat(使い回す。呼ぶ側が中身を全部入れ直す)。
static func _shared_box() -> StyleBoxFlat:
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.anti_aliasing = true
	_box.draw_center = true
	_box.shadow_size = 0
	_box.shadow_offset = Vector2.ZERO
	return _box


# 鍵 1 つ。sink は押した沈み(0〜1)、fill は押した光の強さ(0〜1)、hint は手がかりの光、glow はその縁の色の強さ(点滅を弱める時は 0.2)。
# 押した光は中を塗り、手がかりは縁だけを太くする(形で分ける。画面設計書 §8)。下に床の色の段があり、押すと沈んで段が隠れる。
static func draw_key(ci: CanvasItem, k: int, r: Rect2, sink: float, fill: float, hint: bool = false, glow: float = 1.0, alpha: float = 1.0) -> void:
	var s := r.size.x / B.KEY_W
	var lip := 7.0 * s * (1.0 - sink)
	var rr := Rect2(r.position + Vector2(0, B.KEY_SINK_PX * s * sink), r.size)
	var sb := _shared_box()  # 毎フレーム作らずに 1 つを使い回す(描く時に中身が写される)
	sb.set_corner_radius_all(int(12 * s))
	sb.bg_color = Color(C_KEY_FILL.lerp(C_PRESS, fill), alpha)
	sb.border_color = Color(C_KEY_EDGE.lerp(C_HINT, glow if hint else 0.0), alpha)
	sb.set_border_width_all(7 if hint else 2)
	sb.shadow_color = Color(C_FLOOR, alpha)  # 下の段
	sb.shadow_size = 1 if lip > 0.5 else 0
	sb.shadow_offset = Vector2(0, lip)
	ci.draw_style_box(sb, rr)
	if fill < 0.5:
		ci.draw_line(rr.position + Vector2(14 * s, 9 * s), rr.position + Vector2(rr.size.x - 14 * s, 9 * s), Color(C_SPOT, 0.10 * alpha), 2.0)
	var text_c := Color(C_TEXT.lerp(C_FLOOR, fill * 0.85), alpha)
	ci.draw_string(font(800), Vector2(rr.position.x, rr.position.y + rr.size.y * 0.44), S.KEYS[k], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, int(38 * s), text_c)
	ci.draw_string(font(500), Vector2(rr.position.x, rr.position.y + rr.size.y * 0.8), S.NOTE_NAMES[k], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, int(24 * s), text_c)


# 判定の印: ぴったり ●、よい ◐、おしい ○、外れ ×(形で分ける。NFR-11)。
static func draw_grade(ci: CanvasItem, at: Vector2, grade: int, r: float = 11.0, alpha: float = 1.0) -> void:
	match grade:
		0:
			ci.draw_circle(at, r, Color(C_PERFECT, alpha))
		1:
			ci.draw_arc(at, r, 0, TAU, 32, Color(C_GOOD, alpha), 3.0, true)
			var half := PackedVector2Array()
			for k in 17:
				var a := PI / 2 + PI * k / 16.0  # 下 → 左 → 上(左の半分を塗る)
				half.append(at + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(half, Color(C_GOOD, alpha))
		2:
			ci.draw_arc(at, r, 0, TAU, 32, Color(C_OK, alpha), 3.0, true)
		_:
			ci.draw_line(at + Vector2(-r, -r), at + Vector2(r, r), Color(C_MISS, alpha), 4.0, true)
			ci.draw_line(at + Vector2(-r, r), at + Vector2(r, -r), Color(C_MISS, alpha), 4.0, true)


# お手本の位置の印 ◆(filled が偽なら ◇。判定の後に、押した位置と比べる時)。
static func draw_diamond(ci: CanvasItem, at: Vector2, r: float, c: Color, filled: bool = true) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	if filled:
		ci.draw_colored_polygon(pts, c)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, c, 2.0, true)


# ギターのピック(残機)。filled が偽なら線だけ(失った)。
static func draw_pick(ci: CanvasItem, at: Vector2, s: float, c: Color, filled: bool = true) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in [Vector2(-1.0, -0.62), Vector2(-0.72, -0.95), Vector2(0, -1.05), Vector2(0.72, -0.95), Vector2(1.0, -0.62),
			Vector2(0.62, 0.3), Vector2(0.2, 0.95), Vector2(0, 1.05), Vector2(-0.2, 0.95), Vector2(-0.62, 0.3)]:
		pts.append(at + p * s)
	if filled:
		ci.draw_colored_polygon(pts, c)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, c, 2.0, true)
