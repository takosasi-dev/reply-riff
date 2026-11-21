# ソースの決まりのテスト(AC-22・INV-2・INV-7・NFR-15)と、同梱の字体に画面の文字が全部あるか(ブラウザで目で見られない分)。
extends "res://tests/suite.gd"

const Kit := preload("res://ui/kit.gd")


static func _sources(dir: String) -> Array:
	var out: Array = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


static func _code(path: String) -> String:
	# コメントを除いた本文
	var lines: Array = []
	for l: String in FileAccess.get_file_as_string(path).split("\n"):
		var k := l.find("#")
		lines.append(l if k < 0 else l.substr(0, k))
	return "\n".join(lines)


func test_ac22_core_is_pure() -> bool:
	var re := RegEx.create_from_string("\\b(sin|cos|randf|randi|randf_range|randi_range|Time|AudioServer|AudioStream\\w*|Input)\\b|extends\\s+Node")
	for p: String in _sources("res://core"):
		var code := _code(p)
		ok(code.contains("extends RefCounted"), "%s は RefCounted" % p)
		var m := re.search(code)
		ok(m == null, "%s に %s がある" % [p, m.get_string() if m != null else ""])
	return true


func test_ac22_no_text_outside_strings() -> bool:
	# 日本語の文字列リテラルは core/strings.gd の外に無い
	var lit := RegEx.create_from_string("\"([^\"\\\\\\n]|\\\\.)*\"")
	var ja := RegEx.create_from_string("[\\x{3040}-\\x{30FF}\\x{4E00}-\\x{9FFF}]")
	for dir: String in ["res://core", "res://ui", "res://audio", "res://save"]:
		for p: String in _sources(dir):
			if p.ends_with("strings.gd"):
				continue
			for m: RegExMatch in lit.search_all(_code(p)):
				ok(ja.search(m.get_string()) == null, "%s の文言 %s は strings.gd へ" % [p, m.get_string()])
	return true


func test_font_has_all_chars() -> bool:
	var f := load(Kit.SANS) as Font
	ok(f != null, "字体を読める")
	if f == null:
		return true
	var lit := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	var missing := ""
	for m: RegExMatch in lit.search_all(FileAccess.get_file_as_string("res://core/strings.gd")):
		for c in m.get_string(1):
			if c != "%" and not f.has_char(c.unicode_at(0)) and not missing.contains(c):
				missing += c
	eq(missing, "", "字体に無い文字")
	for c in "0123456789,+−×":
		ok(f.has_char(c.unicode_at(0)), "数字と記号 %s" % c)
	# v0.3.0: 題字の字体(Shrikhand)は題字と数字の字。日本語は Noto に落ちる(豆腐を出さない)
	var d := load(Kit.DISPLAY) as Font
	ok(d != null, "題字の字体を読める")
	for c in "ReplyRif0123456789,+":
		ok(d != null and d.has_char(c.unicode_at(0)), "題字の字体に %s" % c)
	var dv := Kit.display()
	ok(dv.fallbacks.size() == 1 and (dv.fallbacks[0] as Font).has_char("点".unicode_at(0)), "題字の字体の「点」は Noto に落ちる")
	return true


# v0.3.0: 全部の Control が通る Theme が project に付いていて、ボタンの 5 つの状態と選んだ印・枠・スクロールバー・メニューがある。
func test_project_theme() -> bool:
	eq(ProjectSettings.get_setting("gui/theme/custom"), "res://ui/theme.tres", "project の gui/theme/custom")
	var t := load("res://ui/theme.tres") as Theme
	ok(t != null, "Theme を読める")
	if t == null:
		return true
	for st: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		ok(t.has_stylebox(st, "Button"), "Button の %s" % st)
	ok(t.get_type_variation_base("SelButton") == &"Button" and t.has_stylebox("normal", "SelButton"), "選んでいるボタン")
	ok(t.has_stylebox("read_only", "TextEdit") and t.has_stylebox("grabber", "VScrollBar") and t.has_stylebox("panel", "PopupMenu"), "共有の枠・スクロールバー・右クリックのメニュー")
	ok(t.has_stylebox("slider", "HSlider") and t.has_icon("checked", "CheckBox") and t.has_stylebox("normal", "LineEdit"), "スライダー・チェック・入力欄")
	ok(ThemeDB.get_project_theme() != null, "動いている間の project の Theme")
	return true


static func _lum(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	for i in 3:
		ch[i] = ch[i] / 12.92 if ch[i] <= 0.03928 else pow((ch[i] + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func _ratio(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# v0.3.0: 字と地のコントラスト(4.5:1 以上。大きな字は 3:1 以上)。地は壁・板・選んだ板・帯、字は生成り・弱い字・意味の色。
func test_palette_contrast() -> bool:
	var sel_fill := Color("4A2633")
	for pair: Array in [[Kit.C_TEXT, Kit.C_BG], [Kit.C_TEXT, Kit.C_BG2], [Kit.C_TEXT, Kit.C_PANEL], [Kit.C_TEXT, sel_fill], [Kit.C_TEXT, Kit.C_KEY_FILL],
			[Kit.C_DIM, Kit.C_BG], [Kit.C_DIM, Kit.C_BG2], [Kit.C_CALL, Kit.C_BG2], [Kit.C_PRESS, Kit.C_BG2], [Kit.C_PERFECT, Kit.C_BG2],
			[Kit.C_MISS, Kit.C_BG2], [Kit.C_WARN, Kit.C_BG2], [Kit.C_LAYER, Kit.C_FLOOR], [Kit.C_FLOOR, Kit.C_LAYER], [Kit.C_FLOOR, Kit.C_PRESS]]:
		var r := _ratio(pair[0], pair[1])
		ok(r >= 4.5, "%s の上の %s: %.2f" % [pair[1].to_html(false), pair[0].to_html(false), r])
	var big := _ratio(Kit.C_CRIMSON, Kit.C_BG)
	ok(big >= 3.0, "題字の Riff(大きな字): %.2f" % big)
	return true


func test_audio_budget() -> bool:
	# 書き出しに入る音(取り込んだ後の .sample)の合計が AUDIO_BUDGET 以下(§9.10・NFR-7)。控えの mix/ は取り込まない
	var total := 0
	var n := 0
	for f: String in DirAccess.get_files_at("res://.godot/imported"):
		if f.ends_with(".sample"):
			total += FileAccess.open("res://.godot/imported/" + f, FileAccess.READ).get_length()
			n += 1
			ok(not f.begins_with("mix_"), "控えの %s は取り込まない" % f)
	eq(n, 15, "8 つの音・4 層・クリック・外れ・終わり")
	ok(total > 0 and total <= B.AUDIO_BUDGET, "音の合計 %d バイト" % total)
	print("  音の合計(取り込んだ後): %d バイト" % total)
	return true
