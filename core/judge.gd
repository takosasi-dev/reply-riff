# 判定(仕様書 §9.6・INV-4)。1 音目は拍との差を広い窓で、2 音目からは押した間隔とお手本の間隔の差だけで段を決める。
# 比べは整数で行う(|d| × 1000 ≤ ms × 120)。押した記録は [tick, キー] の並び。
extends RefCounted

const B := preload("res://core/balance.gd")
const TL := preload("res://core/timeline.gd")

const PERFECT := 0
const GOOD := 1
const OK := 2
const MISS := 3


# お手本の i 番目の音の、返しでの tick m(i)。
static func note_tick(t: int, turn: Dictionary, i: int) -> int:
	return TL.reply_start(t) + int(turn["pos"][i]) * B.EIGHTH_TICKS


static func judge_tick(t: int, turn: Dictionary) -> int:
	return note_tick(t, turn, turn["pos"].size() - 1) + B.JUDGE_DELAY


# 受け付けの間に入る押した tick か。
static func in_window(t: int, turn: Dictionary, p: int) -> bool:
	var first := note_tick(t, turn, 0)
	var last := note_tick(t, turn, turn["pos"].size() - 1)
	return (first - p) * 1000 <= B.FIRST_MS * B.TICK_HZ and (p - last) * 1000 <= (B.FIRST_MS + B.OK_MS) * B.TICK_HZ


static func within(ticks: int, ms: int) -> bool:
	return absi(ticks) * 1000 <= ms * B.TICK_HZ


# 間隔の差 d(tick)の段。
static func gap_grade(d: int) -> int:
	if within(d, B.PERFECT_MS):
		return PERFECT
	if within(d, B.GOOD_MS):
		return GOOD
	if within(d, B.OK_MS):
		return OK
	return MISS


# 音ごとの段を返す。長さは音の数 + 多く押した数(多い分は 1 つごとに外れ)。
# 1 音目は窓に入れば PERFECT(段は付けないが、点は 300 でぴったりと同じ。ぴったりの数にも入れる)。
static func grades(t: int, turn: Dictionary, presses: Array) -> Array:
	var n: int = turn["pos"].size()
	var out: Array = []
	for i in n:
		if i >= presses.size():
			out.append(MISS)  # 足りない音
			continue
		var p: int = presses[i][0]
		var g := MISS
		if int(presses[i][1]) == int(turn["keys"][i]):
			if i == 0:
				g = PERFECT if within(p - note_tick(t, turn, 0), B.FIRST_MS) else MISS
			else:
				var d: int = (p - int(presses[i - 1][0])) - (note_tick(t, turn, i) - note_tick(t, turn, i - 1))
				g = gap_grade(d)
		out.append(g)
	for k in maxi(presses.size() - n, 0):
		out.append(MISS)
	return out
