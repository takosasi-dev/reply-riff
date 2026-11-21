# 通し日数・日替わりの種・共有する文字のテスト(AC-16・共通 §3 の 13・E-16)。
extends "res://tests/suite.gd"

const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Score := preload("res://core/score.gd")


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
		"ReplyRiff 2026-11-19(今日の曲・1回目)\n8 小節 / 外れ 1 回 / ぴったり 31 / 12,400点(二番手)\nhttps://takosasi-dev.github.io/reply-riff/", "§9.11 の例")
	eq(Share.make("2026-11-19", 0, false, _res(900, false, 3, 3, 0)),
		"ReplyRiff 2026-11-19(今日の曲)\n3 回目で止まった / 外れ 3 回 / ぴったり 0 / 900点(路上)\nhttps://takosasi-dev.github.io/reply-riff/", "2 回目以降・止まった")
	eq(Share.make("2027-01-01", 1, true, _res(18100, true, 8, 0, 39)).split("\n")[0], "ReplyRiff 2027-01-01(練習)", "練習は 1 回目でも「練習」")
	eq(S.URL.count("https://"), 1, "URL は strings.gd の 1 か所")
	return true


# v0.3.1: 段位は区切りの点ちょうどで 1 つ上がる(区切りを決め直してもこのテストは生きる)。名前は区切りより 1 つ多い。
func test_rank_boundaries() -> bool:
	eq(Score.rank(0), 0, "0 点はいちばん下")
	eq(Score.rank(18100), B.RANK_POINTS.size(), "最大の点はいちばん上")
	eq(S.RANK_NAMES.size(), B.RANK_POINTS.size() + 1, "名前の数 = 区切りの数 + 1")
	for i in B.RANK_POINTS.size():
		var p: int = B.RANK_POINTS[i]
		eq(Score.rank(p - 1), i, "%d 点は段 %d" % [p - 1, i])
		eq(Score.rank(p), i + 1, "%d 点は段 %d" % [p, i + 1])
		ok(p > 0 and p <= 18100 and (i == 0 or p > B.RANK_POINTS[i - 1]), "区切りは 0〜18,100 の中で上がっていく")
	for n: String in S.RANK_NAMES:
		ok(not n.contains(S.RES_BADGE) and not n.contains("記録"), "段位の名前は新しい記録と同じ事を言わない: " + n)
	eq(Share.make("2026-11-19", 1, false, _res(B.RANK_POINTS[2], true, 8, 0, 0)).split("\n")[1].get_slice("(", 1), S.RANK_NAMES[3] + ")", "共有の文の段位")
	return true


func test_share_from_real_result() -> bool:
	var res: Dictionary = play_bot(1, Bots.EXACT)["sim"].result()
	eq(Share.make("2026-11-19", 1, false, res).split("\n")[1], "8 小節 / 外れ 0 回 / ぴったり 39 / 18,100点(ワンマン)", "正解 bot の結果")
	return true
