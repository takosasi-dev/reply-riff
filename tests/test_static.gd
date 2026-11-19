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
