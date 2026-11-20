# 画面の共通部品(色・字体・ラベル・ボタン・置き場所)と、背景・鍵・判定の印の絵。画面設計書 §8 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。作りは KeyFlak の ui/kit.gd。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"

const C_BG := Color("10131A")
const C_BG2 := Color("161B26")
const C_KEY_EDGE := Color("8B95A5")
const C_KEY_FILL := Color("1C222C")
const C_PRESS := Color("6BB8FF")
const C_HINT := Color("FFE066")
const C_RULER := Color("3A4250")
const C_NOW := Color("E6E6E6")
const C_CALL := Color("FFE066")
const C_PERFECT := Color("7EE787")
const C_GOOD := Color("6BB8FF")
const C_OK := Color("8B95A5")
const C_MISS := Color("FF6B6B")
const C_LAYER := Color("C792EA")
const C_TEXT := Color("E6E6E6")
const C_DIM := Color("8B95A5")
const C_SEL := Color("6BB8FF")
const C_WARN := Color("FFB84D")

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.anti_aliasing = true
	return s


# ボタン。node_name は自動の確認が押す時の目印。キーボードでの選択は ui/menu.gd が見た目を変える。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # 矢印を Godot のフォーカスの移動に使わせない
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	set_selected(b, false)
	b.add_theme_stylebox_override("pressed", box(Color(C_SEL, 0.3), C_SEL, 3))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.02), Color(C_DIM, 0.3), 2))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, C_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(C_DIM, 0.5))
	return b


static func set_selected(b: Button, on: bool) -> void:
	var edge := C_SEL if on else Color(C_TEXT, 0.55)
	var fill := Color(C_SEL, 0.16) if on else Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("normal", box(fill, edge, 3 if on else 2))
	b.add_theme_stylebox_override("hover", box(Color(C_SEL, 0.12), C_SEL, 3))


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


# 背景: 上から下へ 2 色の帯。
static func draw_bg(ci: CanvasItem) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(-2000, -2000), Vector2(3280, -2000), Vector2(3280, 2720), Vector2(-2000, 2720)]),
		PackedColorArray([C_BG, C_BG, C_BG2, C_BG2]))


# 鍵 k の左上。4 つずつ左右に分け、間を 96 空ける(画面設計書 §3)。
static func key_rect(k: int, y: float = B.KEY_Y, scale: float = 1.0) -> Rect2:
	var w := B.KEY_W * scale
	var gap := B.KEY_GAP * scale
	var hand := 4 * w + 3 * gap
	var x0 := (1280.0 - 2 * hand - B.HAND_GAP * scale) / 2
	var x := x0 + (k % 4) * (w + gap) + (0.0 if k < 4 else hand + B.HAND_GAP * scale)
	return Rect2(x, y, w, B.KEY_H * scale)


# 鍵 1 つ。sink は押した沈み(0〜1)、fill は押した光の強さ(0〜1)、hint は手がかりの光、glow はその縁の色の強さ(点滅を弱める時は 0.2)。
# 押した光は中を塗り、手がかりは縁だけを太くする(形で分ける。画面設計書 §8)。
static func draw_key(ci: CanvasItem, k: int, r: Rect2, sink: float, fill: float, hint: bool = false, glow: float = 1.0, alpha: float = 1.0) -> void:
	var rr := Rect2(r.position + Vector2(0, B.KEY_SINK_PX * sink), r.size)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.bg_color = Color(C_KEY_FILL.lerp(C_PRESS, fill), alpha)
	sb.border_color = Color(C_KEY_EDGE.lerp(C_HINT, glow if hint else 0.0), alpha)
	sb.set_border_width_all(7 if hint else 2)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rr)
	var f := font(700)
	var text_c := Color(C_TEXT.lerp(C_BG, fill * 0.8), alpha)
	var big := int(36 * rr.size.x / B.KEY_W)
	var small := int(24 * rr.size.x / B.KEY_W)
	ci.draw_string(f, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.42), S.KEYS[k], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, big, text_c)
	ci.draw_string(font(500), Vector2(rr.position.x, rr.position.y + rr.size.y * 0.8), S.NOTE_NAMES[k], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, small, text_c)


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
