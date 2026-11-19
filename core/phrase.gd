# フレーズを種から作る(仕様書 §9.5・INV-3)。回 1 は決まり、回 2〜8 は回の表に沿って rng で引く。
# 1 回 = { pos: 8 分音符の位置(小さい順), keys: キーの番号, hint: 2 全部 / 1 1 音目 / 0 無し }。操作では変わらない。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")


static func build(seed_value: int) -> Array:
	var rng := Rng.new(seed_value)
	var out: Array = []
	for t in B.TURNS:
		var row: Dictionary = B.TURN_TABLE[t]
		var use: Array = row["keys"]
		var fixed: Array = row["fixed"]
		if not fixed.is_empty():
			out.append({"pos": fixed.duplicate(), "keys": fixed.map(func(_p: int) -> int: return use[0]), "hint": row["hint"]})
			continue
		var n: int = row["n"]
		var pos: Array = []
		var avail: Array = []
		if row["odd_first"]:
			# 1 つ目は「奇数で、8 − 音の数 以下」から選び、残りはそれより後ろから選ぶ
			var firsts: Array = range(1, B.BAR_EIGHTHS - n + 1, 2)
			var first: int = firsts[rng.next_int(firsts.size())]
			pos.append(first)
			avail = range(first + 1, B.BAR_EIGHTHS)
		else:
			for p in B.BAR_EIGHTHS:
				if not row["even"] or p % 2 == 0:
					avail.append(p)
		while pos.size() < n:
			var k := rng.next_int(avail.size())
			pos.append(avail[k])
			avail.remove_at(k)
		pos.sort()
		# キー: 1 音目は使うキーから、2 音目からは前の音の順番 ±2 以内(端で止める)から選ぶ
		var keys: Array = []
		var idx := rng.next_int(use.size())
		keys.append(use[idx])
		for i in range(1, n):
			var lo := maxi(idx - B.KEY_STEP, 0)
			var hi := mini(idx + B.KEY_STEP, use.size() - 1)
			idx = lo + rng.next_int(hi - lo + 1)
			keys.append(use[idx])
		out.append({"pos": pos, "keys": keys, "hint": row["hint"]})
	return out


# その音で光らせるか(FR-12)。
static func lit(turn: Dictionary, i: int) -> bool:
	return int(turn["hint"]) == 2 or (int(turn["hint"]) == 1 and i == 0)
