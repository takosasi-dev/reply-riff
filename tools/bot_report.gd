# bot の数字(仕様書 §9.13・AC-6〜AC-8)を種 1〜20 で回して印字する。
# 実行: python tools/gd.py run res://tools/bot_report.gd
extends SceneTree

const Sim := preload("res://core/sim.gd")
const Bots := preload("res://core/bots.gd")
const DayIdx := preload("res://core/day_index.gd")

const SEEDS := 20


func _initialize() -> void:
	var cases := [["正解", Bots.EXACT, 0], ["ずれ +12", Bots.SHIFT, 12], ["ずれ +22", Bots.SHIFT, 22], ["揺れ ±4", Bots.JITTER, 4],
		["揺れ ±8", Bots.JITTER, 8], ["揺れ ±12", Bots.JITTER, 12], ["何もしない", Bots.IDLE, 0]]
	for c: Array in cases:
		var pts := 0
		var oks := 0
		var fin := 0
		var mn := 1 << 30
		var mx := -1
		for s in range(1, SEEDS + 1):
			var seed_value := DayIdx.day_seed(321 + s)
			var sim := Sim.new(seed_value, Sim.MODE_DAILY)
			var bot := Bots.new(c[1], c[2], s)
			while not sim.is_over():
				bot.act(sim)
				sim.step()
			var r := sim.result()
			pts += int(r["points"])
			oks += int(r["turns_ok"])
			fin += 1 if r["finished"] else 0
			mn = mini(mn, int(r["points"]))
			mx = maxi(mx, int(r["points"]))
		print("%s: 点の平均 %.0f(最小 %d・最大 %d)/ 合った回の平均 %.2f / 最後まで %d/%d" % [c[0], float(pts) / SEEDS, mn, mx, float(oks) / SEEDS, fin, SEEDS])
	quit(0)
