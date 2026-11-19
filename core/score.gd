# 点数(仕様書 §9.7)と、点の 3 桁区切り。整数だけで数える。
# 音ごとの段の点 + 合った回のボーナス 500(1 音目が合い、2 音目からが全部ぴったりならさらに 300)。最大 18,100。
extends RefCounted

const B := preload("res://core/balance.gd")
const J := preload("res://core/judge.gd")


# 1 回ぶんの点。n はお手本の音の数(grades の後ろの多い分は外れ)。
static func turn_points(grades: Array, n: int) -> int:
	var pts := 0
	for g: int in grades:
		pts += B.NOTE_POINTS[g]
	if not grades.has(J.MISS):
		pts += B.TURN_BONUS
		if grades.slice(1, n).all(func(g: int) -> bool: return g == J.PERFECT):
			pts += B.PERFECT_BONUS
	return pts


# 18100 → "18,100"
static func comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
