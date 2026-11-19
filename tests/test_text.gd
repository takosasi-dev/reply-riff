# 通し日数・日替わりの種・共有する文字のテスト(AC-16・共通 §3 の 13・E-16)。
extends "res://tests/suite.gd"

const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")


func test_ac16_day_index_and_seed() -> bool:
	eq(Day.day_index(2026, 1, 1), 0, "2026-01-01 は 0")
	eq(Day.day_index(2026, 11, 19), 322, "2026-11-19 は 322")
	eq(Day.day_index(2027, 1, 1), 365, "2027-01-01 は 365")
	eq(Day.day_index(2025, 12, 31), 0, "それより前は 0(E-16)")
	eq(Day.day_seed(322), (323 * 2654435761 + 0x5252) & 0xFFFFFFFF, "種の式(SALT 0x5252)")
	eq(Day.day_seed(322), 2684279973, "2026-11-19 の種")
	eq(Day.date_string(2026, 1, 5), "2026-01-05", "日付の文字")
	return true


static func _res(points: int, finished: bool, reached: int, missed: int, perfect: int) -> Dictionary:
	return {"points": points, "finished": finished, "reached": reached, "missed_turns": missed, "counts": [perfect, 0, 0, 0], "turns_ok": reached - missed}


func test_ac16_share_text() -> bool:
	eq(Share.make("2026-11-19", 0, true, _res(12400, true, 8, 1, 31)),
		"ReplyRiff 2026-11-19(今日の曲・1回目)\n8 小節 / 外れ 1 回 / ぴったり 31 / 12,400点\nhttps://takosasi-dev.github.io/reply-riff/", "§9.11 の例")
	eq(Share.make("2026-11-19", 0, false, _res(900, false, 3, 3, 0)),
		"ReplyRiff 2026-11-19(今日の曲)\n3 回目で止まった / 外れ 3 回 / ぴったり 0 / 900点\nhttps://takosasi-dev.github.io/reply-riff/", "2 回目以降・止まった")
	eq(Share.make("2027-01-01", 1, true, _res(18100, true, 8, 0, 39)).split("\n")[0], "ReplyRiff 2027-01-01(練習)", "練習は 1 回目でも「練習」")
	eq(S.URL.count("https://"), 1, "URL は strings.gd の 1 か所")
	return true


func test_share_from_real_result() -> bool:
	var res: Dictionary = play_bot(1, Bots.EXACT)["sim"].result()
	eq(Share.make("2026-11-19", 1, false, res).split("\n")[1], "8 小節 / 外れ 0 回 / ぴったり 39 / 18,100点", "正解 bot の結果")
	return true
