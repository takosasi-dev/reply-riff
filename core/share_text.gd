# 人に見せる結果の文字(仕様書 §9.11・共通 §3 の 12)。3 行。
extends RefCounted

const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")


# mode: 0 = 今日の曲、1 = 練習。first_today は今日の曲の 1 回目か。date は "2026-11-19"。result は sim.result()。
static func make(date: String, mode: int, first_today: bool, result: Dictionary) -> String:
	var label: String = S.DAILY_FIRST if mode == 0 and first_today else S.MODE_LABEL[mode]
	var head: String = S.SHARE_DONE if result["finished"] else S.SHARE_STOP % int(result["reached"])
	var body := S.SHARE_BODY % [head, int(result["missed_turns"]), int(result["counts"][0]), Score.comma(int(result["points"]))]
	return "\n".join([S.SHARE_HEAD % [S.NAME, date, label], body, S.URL])
