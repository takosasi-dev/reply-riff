# ui/theme.tres を作る(v0.3.0。画面設計書 §10)。project の gui/theme/custom でこの Theme 1 つを全部の Control に通す。
# 色は ui/kit.gd の物。ボタンは 5 つの状態(normal・hover・focus・pressed・disabled)と、選んでいる印の SelButton。
# 使っていない部品(スライダー・チェック・入力欄・ツールチップ)も、後から足した時に既定の見た目に戻らないよう作っておく。
#     python tools/gd.py run res://tools/make_theme.gd
extends SceneTree

const Kit := preload("res://ui/kit.gd")

const SKEW := Vector2(0.1, 0)  # ボタンの傾き(題字の斜めの字に合わせる)
const LIP := 6  # ボタンの下の段の厚み


func _initialize() -> void:
	var t := Theme.new()
	t.default_font = load(Kit.SANS)
	t.default_font_size = 20

	# ボタン
	t.set_stylebox("normal", "Button", _btn(Kit.C_PANEL, Kit.C_EDGE, 2))
	t.set_stylebox("hover", "Button", _btn(Color("3E2933"), Kit.C_DIM, 2))
	t.set_stylebox("pressed", "Button", _btn(Color("4A2633"), Kit.C_TEXT, 3, true))
	t.set_stylebox("hover_pressed", "Button", _btn(Color("4A2633"), Kit.C_TEXT, 3, true))
	t.set_stylebox("disabled", "Button", _btn(Color("22171D"), Color("45343E"), 2))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Kit.C_TEXT
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(10)
	focus.set_expand_margin_all(4)
	focus.skew = SKEW
	focus.anti_aliasing = true
	t.set_stylebox("focus", "Button", focus)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Kit.C_TEXT)
	t.set_color("font_disabled_color", "Button", Color(Kit.C_DIM, 0.55))
	t.set_color("font_outline_color", "Button", Kit.C_FLOOR)
	t.set_constant("outline_size", "Button", 0)

	# 選んでいるボタン(キーボードの選択。ui/menu.gd が theme_type_variation で切り替える)
	t.set_type_variation("SelButton", "Button")
	var sel := _btn(Color("4A2633"), Kit.C_TEXT, 3)
	sel.shadow_color = Color(Kit.C_CRIMSON, 0.55)
	sel.shadow_size = 14
	sel.shadow_offset = Vector2(0, 3)
	t.set_stylebox("normal", "SelButton", sel)
	t.set_stylebox("hover", "SelButton", sel)
	t.set_stylebox("pressed", "SelButton", _btn(Color("5A2B3A"), Kit.C_TEXT, 3, true))
	t.set_stylebox("hover_pressed", "SelButton", _btn(Color("5A2B3A"), Kit.C_TEXT, 3, true))

	# 字・枠
	t.set_color("font_color", "Label", Kit.C_TEXT)
	t.set_color("font_outline_color", "Label", Kit.C_FLOOR)
	var panel := _box(Color(Kit.C_PANEL, 0.94), Kit.C_EDGE, 2, 10, 16)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	# 共有の文字の枠(TextEdit)と入力欄(LineEdit)
	var field := _box(Color(Kit.C_FLOOR, 0.85), Kit.C_EDGE, 2, 8, 14)
	var field_focus := _box(Color(Kit.C_FLOOR, 0.85), Kit.C_TEXT, 2, 8, 14)
	for ty: String in ["TextEdit", "LineEdit"]:
		t.set_stylebox("normal", ty, field)
		t.set_stylebox("read_only", ty, field)
		t.set_stylebox("focus", ty, field_focus)
		t.set_color("font_color", ty, Kit.C_TEXT)
		t.set_color("font_readonly_color", ty, Kit.C_TEXT)
		t.set_color("font_placeholder_color", ty, Kit.C_DIM)
		t.set_color("font_selected_color", ty, Kit.C_TEXT)
		t.set_color("selection_color", ty, Color(Kit.C_CRIMSON, 0.6))
		t.set_color("caret_color", ty, Kit.C_TEXT)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))

	# スクロールバー
	for ty: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", ty, _box(Color(Kit.C_FLOOR, 0.6), Color(0, 0, 0, 0), 0, 4, 2))
		t.set_stylebox("scroll_focus", ty, _box(Color(Kit.C_FLOOR, 0.6), Color(0, 0, 0, 0), 0, 4, 2))
		t.set_stylebox("grabber", ty, _box(Kit.C_EDGE, Color(0, 0, 0, 0), 0, 4, 4))
		t.set_stylebox("grabber_highlight", ty, _box(Kit.C_DIM, Color(0, 0, 0, 0), 0, 4, 4))
		t.set_stylebox("grabber_pressed", ty, _box(Kit.C_TEXT, Color(0, 0, 0, 0), 0, 4, 4))

	# 右クリックのメニュー・ツールチップ
	t.set_stylebox("panel", "PopupMenu", _box(Kit.C_PANEL, Kit.C_EDGE, 2, 8, 8))
	t.set_stylebox("hover", "PopupMenu", _box(Color(Kit.C_CRIMSON, 0.55), Color(0, 0, 0, 0), 0, 4, 4))
	var sep := StyleBoxLine.new()
	sep.color = Kit.C_EDGE
	sep.thickness = 2
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_color("font_color", "PopupMenu", Kit.C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Kit.C_TEXT)
	t.set_color("font_disabled_color", "PopupMenu", Color(Kit.C_DIM, 0.6))
	t.set_color("font_accelerator_color", "PopupMenu", Kit.C_DIM)
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_font("font", "PopupMenu", Kit.font(500))
	t.set_constant("v_separation", "PopupMenu", 10)
	t.set_constant("item_start_padding", "PopupMenu", 12)
	t.set_constant("item_end_padding", "PopupMenu", 12)
	t.set_stylebox("panel", "TooltipPanel", _box(Kit.C_PANEL, Kit.C_EDGE, 2, 6, 8))
	t.set_color("font_color", "TooltipLabel", Kit.C_TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	# スライダー・チェック(今は使っていない。後から足しても揃うように)
	var grab := _dot(22, Kit.C_TEXT, Kit.C_FLOOR)
	var grab_hi := _dot(22, Color.WHITE, Kit.C_CRIMSON)
	var grab_off := _dot(22, Kit.C_EDGE, Kit.C_FLOOR)
	for ty: String in ["HSlider", "VSlider"]:
		var rail := _box(Kit.C_FLOOR, Kit.C_EDGE, 1, 4, 3)
		t.set_stylebox("slider", ty, rail)
		t.set_stylebox("grabber_area", ty, _box(Kit.C_CRIMSON, Color(0, 0, 0, 0), 0, 4, 3))
		t.set_stylebox("grabber_area_highlight", ty, _box(Color("E0566B"), Color(0, 0, 0, 0), 0, 4, 3))
		t.set_icon("grabber", ty, grab)
		t.set_icon("grabber_highlight", ty, grab_hi)
		t.set_icon("grabber_disabled", ty, grab_off)
	for ty: String in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", ty, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 6))
		t.set_stylebox("hover", ty, _box(Color(Kit.C_PANEL, 0.8), Color(0, 0, 0, 0), 0, 6, 6))
		t.set_stylebox("pressed", ty, _box(Color(Kit.C_PANEL, 0.8), Color(0, 0, 0, 0), 0, 6, 6))
		t.set_stylebox("disabled", ty, _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 6))
		t.set_stylebox("focus", ty, focus)
		t.set_color("font_color", ty, Kit.C_TEXT)
		t.set_color("font_hover_color", ty, Kit.C_TEXT)
		t.set_color("font_pressed_color", ty, Kit.C_TEXT)
		t.set_color("font_disabled_color", ty, Color(Kit.C_DIM, 0.55))
	var on := _check(24, true)
	var off := _check(24, false)
	t.set_icon("checked", "CheckBox", on)
	t.set_icon("unchecked", "CheckBox", off)
	t.set_icon("radio_checked", "CheckBox", _dot(24, Kit.C_TEXT, Kit.C_CRIMSON))
	t.set_icon("radio_unchecked", "CheckBox", _dot(24, Kit.C_EDGE, Kit.C_FLOOR))
	t.set_icon("checked", "CheckButton", on)
	t.set_icon("unchecked", "CheckButton", off)

	var err := ResourceSaver.save(t, "res://ui/theme.tres")
	print("ui/theme.tres: %s" % ("OK" if err == OK else "失敗 %d" % err))
	quit(0 if err == OK else 1)


# ボタンの板: 傾き・角の丸み・下の段(床の色の影を真下にずらす)。down なら段が沈む(押した)。
static func _btn(bg: Color, edge: Color, width: int, down: bool = false) -> StyleBoxFlat:
	var s := _box(bg, edge, width, 10, 0)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 6 + (3 if down else 0)
	s.content_margin_bottom = 6 - (3 if down else 0)
	s.skew = SKEW
	s.shadow_color = Kit.C_FLOOR
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, 2 if down else LIP)
	return s


static func _box(bg: Color, edge: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


# 丸い印の絵(スライダーのつまみ・ラジオ)。
static func _dot(n: int, edge: Color, fill: Color) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length()
			if d <= c - 3:
				img.set_pixel(x, y, fill)
			elif d <= c:
				img.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(img)


# チェックの印(四角。入なら中に深紅の四角)。記号の字は使わない。
static func _check(n: int, on: bool) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var edge := x < 2 or y < 2 or x >= n - 2 or y >= n - 2
			if edge:
				img.set_pixel(x, y, Kit.C_TEXT)
			elif on and x >= 6 and y >= 6 and x < n - 6 and y < n - 6:
				img.set_pixel(x, y, Kit.C_CRIMSON)
			else:
				img.set_pixel(x, y, Kit.C_FLOOR)
	return ImageTexture.create_from_image(img)
