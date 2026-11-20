# core の決まりのテスト(AC-2〜AC-15・E-2〜E-6・NFR-5)。sim を直接組んで押し、events と snapshot を値で確かめる。
extends "res://tests/suite.gd"

const Phrase := preload("res://core/phrase.gd")
const Score := preload("res://core/score.gd")


func test_ac2_same_log_same_result_100() -> bool:
	var a := play_bot(7, Bots.JITTER, 12)
	var want: Dictionary = a["sim"].result()
	for k in 100:
		var r := replay(7, a["log"]).result()
		if r != want:
			eq(r, want, "%d 回目" % k)
			break
	ok(int(want["turns_ok"]) > 0 and int(want["counts"][1]) + int(want["counts"][2]) > 0, "揺れで段が混ざる(試しとして意味がある)")
	return true


func test_ac4_timeline() -> bool:
	for t in 8:
		eq(TL.call_start(t), 288 + 576 * t, "回 %d のお手本" % t)
		eq(TL.reply_start(t), 288 + 576 * t + 288, "回 %d の返し" % t)
		eq(TL.section(TL.call_start(t)), TL.CALL, "お手本の頭")
		eq(TL.section(TL.call_start(t) - 1), TL.COUNT if t == 0 else TL.REPLY, "お手本の 1 つ前")
		eq(TL.section(TL.reply_start(t)), TL.REPLY, "返しの頭")
		eq(TL.turn_of(TL.reply_start(t) + 287), t, "返しの終わりまで同じ回")
	eq(TL.section(0), TL.COUNT, "数え")
	eq(TL.section(4895), TL.REPLY, "回 8 の返しの終わり")
	eq(TL.section(4896), TL.SONG, "自分の曲が 4896 から")
	eq(TL.section(7199), TL.SONG, "7199 まで自分の曲")
	eq(TL.section(7200), TL.END, "7200 で終わり")
	var r := play_bot(3, Bots.EXACT)
	eq(r["sim"].tick, 7200, "最後まで行くと 7200 で止まる")
	eq(r["sim"].over_reason, "end", "曲の終わり")
	eq(of_type(r["events"], "beat").size(), 100, "拍は 72 tick ごとに 100 回")
	return true


func test_ac5_turn1_fixed_any_seed() -> bool:
	for s in range(1, 101):
		var p := Phrase.build(s)
		if p[0]["pos"] != [0, 2, 4, 5] or p[0]["keys"] != [3, 3, 3, 3]:
			eq(p[0], {}, "種 %d の回 1" % s)
			break
	eq(Phrase.build(0)[0]["pos"], [0, 2, 4, 5], "種 0 でも")
	return true


func test_ac6_exact_bot_max_points() -> bool:
	for s: int in [1, 322, 0xBEEF]:
		var r := play_bot(s, Bots.EXACT)
		var res: Dictionary = r["sim"].result()
		eq(res["turns_ok"], 8, "種 %d: 8 回とも合う" % s)
		eq(res["counts"], [39, 0, 0, 0], "種 %d: 39 音が全部ぴったり" % s)
		eq(res["points"], 18100, "種 %d: 18,100 点" % s)
		eq(res["finished"], true, "最後まで")
		eq(res["lives"], 3, "残機は減らない")
	return true


func test_ac7_shift_100ms_all_perfect() -> bool:
	var res: Dictionary = play_bot(5, Bots.SHIFT, 12)["sim"].result()
	eq(res["turns_ok"], 8, "一定の遅れ 100 ms でも 8 回とも合う")
	eq(res["counts"], [39, 0, 0, 0], "2 音目からは全部ぴったり(遅れが消える)")
	var early: Dictionary = play_bot(5, Bots.SHIFT, -21)["sim"].result()
	eq(early["turns_ok"], 8, "早い側の 175 ms も窓の中")
	return true


func test_ac8_shift_183ms_first_out() -> bool:
	var r := play_bot(5, Bots.SHIFT, 22)
	var judges := of_type(r["events"], "judge")
	eq(judges[0]["grades"][0], J.MISS, "1 音目が窓の外")
	eq(of_type(r["events"], "turn_miss").size(), 3, "外れが 3 回で止まる")
	eq(r["sim"].over_reason, "lives", "残機 0")
	return true


func test_ac9_gap_grades() -> bool:
	eq([J.gap_grade(4), J.gap_grade(10), J.gap_grade(17), J.gap_grade(19)], [J.PERFECT, J.GOOD, J.OK, J.MISS], "4・10・17・19 tick")
	eq([J.gap_grade(-4), J.gap_grade(-10), J.gap_grade(-17), J.gap_grade(-19)], [J.PERFECT, J.GOOD, J.OK, J.MISS], "早い側も同じ")
	eq([J.gap_grade(5), J.gap_grade(6), J.gap_grade(18)], [J.PERFECT, J.GOOD, J.OK], "境目(45 ms = 5.4 tick、150 ms = 18 tick)")
	# 回 1 の最後の音だけをずらす(その前の間隔は変わらない)
	for d: int in [4, 10, 17, 19]:
		var sim := Sim.new(1, Sim.MODE_DAILY)
		run_to(sim, TL.reply_start(0) - 30)
		var ticks := model_ticks(sim, 0)
		ticks[3] += d
		var ev := reply(sim, 0, ticks, [3, 3, 3, 3])
		var g: Array = of_type(ev, "judge")[0]["grades"]
		eq(g[3], J.gap_grade(d), "最後の音が +%d tick" % d)
		eq(g.slice(0, 3), [J.PERFECT, J.PERFECT, J.PERFECT], "前の 3 音はぴったり")
	return true


func test_ac10_wrong_short_extra() -> bool:
	var cases := {"キーを 1 つ違えた": [[0, 0, 0, 0], [3, 3, 2, 3]], "1 音足りない": [[0, 0, 0], [3, 3, 3]],
		"1 音多い": [[0, 0, 0, 0, 8], [3, 3, 3, 3, 3]]}
	for name: String in cases:
		var sim := Sim.new(1, Sim.MODE_DAILY)
		run_to(sim, TL.reply_start(0) - 30)
		var m := model_ticks(sim, 0)
		var offs: Array = cases[name][0]
		var ticks: Array = []
		for i in offs.size():
			ticks.append(m[mini(i, 3)] + int(offs[i]))
		var ev := reply(sim, 0, ticks, cases[name][1])
		eq(of_type(ev, "turn_miss").size(), 1, name + "で外れ")
		eq(sim.lives, 2, name + "で残機が 1 減る")
	return true


func test_ac11_layers_and_lives() -> bool:
	var r := play_bot(9, Bots.EXACT)
	var layers: Array = of_type(r["events"], "turn_ok").map(func(e: Dictionary) -> int: return e["layers"])
	eq(layers, [1, 2, 3, 4, 4, 4, 4, 4], "合うと層が 1 つ増え、4 で止まる")
	var sim := Sim.new(9, Sim.MODE_DAILY)
	var ev := run(sim, 100000)
	eq(of_type(ev, "turn_miss").map(func(e: Dictionary) -> int: return e["lives"]), [2, 1, 0], "外れると残機が 1 減る")
	eq(sim.tick, J.judge_tick(2, sim.phrase[2]), "残機 0 の判定の step で終わる")
	eq(ev[-1]["type"], "over", "最後は over")
	eq(sim.over_reason, "lives", "理由は残機")
	eq(sim.layers, 0, "外れても層は減らない(増えもしない)")
	sim.step()
	eq(sim.tick, J.judge_tick(2, sim.phrase[2]), "終わった後は進まない")
	return true


func test_ac12_phrase_rules_100_seeds() -> bool:
	for s in range(1, 101):
		var p := Phrase.build(s * 7919)
		for t in range(1, 8):
			var row: Dictionary = B.TURN_TABLE[t]
			var turn: Dictionary = p[t]
			var pos: Array = turn["pos"]
			var keys: Array = turn["keys"]
			var use: Array = row["keys"]
			var bad := ""
			if pos.size() != row["n"] or keys.size() != row["n"]:
				bad = "音の数"
			for i in pos.size():
				if pos[i] < 0 or pos[i] > 7 or (i > 0 and pos[i] <= pos[i - 1]):
					bad = "位置の並び"
				if row["even"] and pos[i] % 2 != 0:
					bad = "偶数の位置だけ"
				if not use.has(keys[i]):
					bad = "使うキー"
				elif i > 0 and absi(use.find(keys[i]) - use.find(keys[i - 1])) > 2:
					bad = "隣の音の差 ±2"
			if row["odd_first"] and (pos[0] % 2 == 0 or pos[0] > 8 - int(row["n"])):
				bad = "最初の音は奇数"
			if bad != "":
				eq(turn, {}, "種 %d の回 %d: %s" % [s * 7919, t + 1, bad])
				return true
	# 回 5 は 1 か 3、回 7 は 1 だけ
	var firsts5 := {}
	for s in range(1, 201):
		var p := Phrase.build(s)
		firsts5[p[4]["pos"][0]] = true
		eq(p[6]["pos"][0], 1, "回 7 の 1 音目")
	eq(firsts5.keys().map(func(x: int) -> int: return x).filter(func(x: int) -> bool: return x != 1 and x != 3), [], "回 5 の 1 音目は 1 か 3")
	return true


func test_ac13_phrase_not_changed_by_input() -> bool:
	var a: Sim = play_bot(77, Bots.EXACT)["sim"]
	var b: Sim = play_bot(77, Bots.JITTER, 30)["sim"]
	var c: Sim = play_bot(77, Bots.IDLE)["sim"]
	eq(a.phrase, b.phrase, "押し方が違ってもフレーズは同じ")
	eq(a.phrase, c.phrase, "押さなくても同じ")
	eq(a.phrase, Phrase.build(77), "phrase.build(seed) だけで決まる")
	ok(a.phrase != Phrase.build(78), "種が違えば違う")
	return true


func test_ac14_song_notes() -> bool:
	var sim := Sim.new(11, Sim.MODE_DAILY)
	run_to(sim, TL.reply_start(0) - 30)
	reply(sim, 0, model_ticks(sim, 0), [3, 3, 2, 3])  # 回 1 は外れ
	run_to(sim, TL.reply_start(1) - 30)
	reply(sim, 1, model_ticks(sim, 1, 3), sim.phrase[1]["keys"])  # 回 2 は 3 tick 遅れて合う
	var bot := Bots.new(Bots.EXACT)
	var ev: Array = []
	while not sim.is_over():
		bot.act(sim)
		var at: int = sim.tick
		sim.step()
		for e: Dictionary in sim.events():
			if e["type"] == "song_note":
				e["at"] = at
				ev.append(e)
	var bar0 := ev.filter(func(e: Dictionary) -> bool: return e["at"] < B.SONG_START + 288)
	eq(bar0.map(func(e: Dictionary) -> Array: return [e["at"] - B.SONG_START, e["key"], e["own"]]),
		[[0, 3, false], [72, 3, false], [144, 3, false], [180, 3, false]], "外れた回はお手本を薄い音で")
	var bar1 := ev.filter(func(e: Dictionary) -> bool: return e["at"] >= B.SONG_START + 288 and e["at"] < B.SONG_START + 576)
	var want: Array = []
	for i in sim.phrase[1]["pos"].size():
		want.append([int(sim.phrase[1]["pos"][i]) * 36 + 3, sim.phrase[1]["keys"][i], true])
	eq(bar1.map(func(e: Dictionary) -> Array: return [e["at"] - B.SONG_START - 288, e["key"], e["own"]]), want, "合った回は押した音と位置で")
	eq(ev.size(), 39, "8 小節で 39 音")
	return true


func test_ac15_rewind() -> bool:
	var sim := Sim.new(4, Sim.MODE_DAILY)
	eq(sim.snapshot()["turn"], -1, "数えの間は回が無い")
	run_to(sim, 100)
	sim.rewind_to_turn()
	eq(sim.tick, 0, "回 1 は 0 へ")
	var bot := Bots.new(Bots.EXACT)
	while sim.judged < 2:
		bot.act(sim)
		sim.step()
	run_to(sim, TL.reply_start(2))
	sim.queue_press(sim.phrase[2]["keys"][0])
	run(sim, 2)
	eq(sim.presses[2].size(), 1, "回 3 で 1 音押した")
	var before := [sim.points, sim.layers, sim.lives, sim.turn_grades.size()]
	sim.rewind_to_turn()
	eq(sim.tick, TL.call_start(2) - 288, "回 3 のお手本の 1 小節前")
	eq(sim.presses[2], [], "その回の押した記録が消える")
	eq(sim.presses[1].size(), 4, "前の回の記録は残る")
	# 判定済みの回 2 の返しの小節をもう一度通っても、二重に判定しない
	run_to(sim, TL.call_start(2))
	eq([sim.points, sim.layers, sim.lives, sim.turn_grades.size()], before, "点・層・残機が二重に動かない")
	return true


func test_rewind_in_song_and_over() -> bool:
	var sim := Sim.new(4, Sim.MODE_DAILY)
	var bot := Bots.new(Bots.EXACT)
	while sim.tick < B.SONG_START + 300:
		bot.act(sim)
		sim.step()
	sim.rewind_to_turn()
	eq(sim.tick, B.SONG_START + 288, "自分の曲の間は今の小節の頭へ")
	while not sim.is_over():
		sim.step()
	var t: int = sim.tick
	sim.rewind_to_turn()
	eq(sim.tick, t, "終わった後は戻らない")
	return true


func test_e2_e3_presses_outside_window() -> bool:
	var sim := Sim.new(1, Sim.MODE_DAILY)
	run_to(sim, TL.call_start(0) + 10)
	sim.queue_press(3)  # お手本の間(E-2)
	run_to(sim, TL.reply_start(0) - 22)
	sim.queue_press(3)  # 1 音目の窓より 1 tick 早い(E-3)
	run(sim, 1)
	eq(sim.presses[0], [], "受け付けの間の外は判定に使わない")
	run_to(sim, TL.reply_start(0) - 21)
	sim.queue_press(3)
	run(sim, 1)
	eq(sim.presses[0].size(), 1, "窓の端(−21 tick = 175 ms)は入る")
	var last := J.note_tick(0, sim.phrase[0], 3)
	ok(J.in_window(0, sim.phrase[0], last + 39) and not J.in_window(0, sim.phrase[0], last + 40), "終わりは最後の音 +39 tick まで")
	eq(J.judge_tick(0, sim.phrase[0]), last + 40, "判定は最後の音 +40")
	return true


func test_e4_same_tick_two_presses() -> bool:
	var sim := Sim.new(1, Sim.MODE_DAILY)
	run_to(sim, TL.reply_start(0))
	sim.queue_press(3)
	sim.queue_press(5)
	run(sim, 1)
	eq(sim.presses[0], [[TL.reply_start(0), 3], [TL.reply_start(0), 5]], "届いた順に、差は 0 tick")
	sim.queue_press(9)
	sim.queue_press(-1)
	run(sim, 1)
	eq(sim.presses[0].size(), 2, "0〜7 の外は捨てる")
	return true


func test_e6_last_judge_before_song() -> bool:
	# 回 8 の最後の音が 7 番目なら、判定は 4900(自分の曲の頭 4896 の後)
	var turn := {"pos": [1, 2, 3, 4, 5, 7], "keys": [0, 0, 0, 0, 0, 0], "hint": 0}
	eq(J.judge_tick(7, turn), 4900, "最大 4900")
	var sim := Sim.new(1, Sim.MODE_DAILY)
	sim.phrase[7] = turn
	var bot := Bots.new(Bots.EXACT)
	var order: Array = []
	while sim.tick <= 4900:
		bot.act(sim)
		sim.step()
		for e: Dictionary in sim.events():
			if e["type"] in ["judge", "song_note"]:
				order.append(e["type"])
	eq(order.find("judge") < order.find("song_note") or order.find("song_note") == -1, true, "同じ tick では判定が先")
	eq(sim.judged, 8, "回 8 まで判定")
	return true


func test_call_notes_and_hints() -> bool:
	var r := play_bot(21, Bots.EXACT)
	var calls := of_type(r["events"], "call_note")
	eq(calls.size(), 39, "お手本の音は 39")
	var lit_by_turn := [0, 0, 0, 0, 0, 0, 0, 0]
	for e: Dictionary in calls:
		if e["lit"]:
			lit_by_turn[e["turn"]] += 1
	eq(lit_by_turn, [4, 4, 4, 5, 1, 1, 0, 0], "回 1〜4 は全部、5〜6 は 1 音目だけ、7〜8 は無し")
	var sim := Sim.new(21, Sim.MODE_DAILY)
	run_to(sim, TL.call_start(0) + 72 + 5)
	var snap := sim.snapshot()
	eq(snap["lit"], [3], "鳴っている音のキーが光る(snapshot)")
	eq(snap["call_pos"], [0, 2], "鳴った音の位置")
	eq(snap["section"], TL.CALL, "お手本の区間")
	return true


func test_marks_until_next_call() -> bool:
	var sim := Sim.new(2, Sim.MODE_DAILY)
	var bot := Bots.new(Bots.EXACT)
	while sim.judged < 1:
		bot.act(sim)
		sim.step()
	eq(sim.snapshot()["marks"], [[0, J.PERFECT], [2, J.PERFECT], [4, J.PERFECT], [5, J.PERFECT]], "判定の印")
	run_to(sim, TL.call_start(1))
	eq(sim.snapshot()["marks"], [], "次の回のお手本が始まると消える")
	return true


func test_score_turn_points() -> bool:
	eq(Score.turn_points([J.PERFECT, J.PERFECT, J.PERFECT, J.PERFECT], 4), 1200 + 800, "全部ぴったり")
	eq(Score.turn_points([J.PERFECT, J.GOOD, J.OK, J.PERFECT], 4), 900 + 500, "合った回のボーナスだけ")
	eq(Score.turn_points([J.PERFECT, J.GOOD, J.MISS, J.PERFECT], 4), 800, "外れた回はボーナス無し")
	eq(Score.turn_points([J.PERFECT, J.PERFECT, J.PERFECT, J.PERFECT, J.MISS], 4), 1200, "多く押した回")
	eq(Score.comma(18100), "18,100", "3 桁ごとにコンマ")
	eq(Score.comma(1234567), "1,234,567", "7 桁")
	eq(Score.comma(0), "0", "0")
	return true


func test_result_fields() -> bool:
	var sim: Sim = play_bot(9, Bots.IDLE)["sim"]
	var res: Dictionary = sim.result()
	eq([res["reached"], res["turns_ok"], res["missed_turns"], res["finished"], res["lives"]], [3, 0, 3, false, 0], "3 回目で止まった")
	eq(res["counts"], [0, 0, 0, 12], "足りない音は全部外れ(4・4・4 音)")
	return true


# NFR-5: 決まった種と bot の結果を固定の値で持ち、Windows と CI(Linux)で同じかを見る。
func test_nfr5_fixed_values() -> bool:
	var res: Dictionary = play_bot(322, Bots.JITTER, 14)["sim"].result()
	eq([res["points"], res["turns_ok"], res["counts"]], FIXED_JITTER, "揺れ bot(種 322、±14 tick)の結果")
	return true


const FIXED_JITTER := [8400, 4, [13, 8, 9, 3]]  # Windows で出した値。CI(Linux)でも同じになること


# 磨き(2026-11-20): 判定の events に、画面がお手本と押した位置を比べるための pos・keys・presses・points が入る。
func test_judge_event_carries_compare_data() -> bool:
	var sim := Sim.new(1, Sim.MODE_DAILY)
	run_to(sim, TL.reply_start(0) - 30)
	var ticks := model_ticks(sim, 0)
	ticks[1] += 10  # 2 音目を「よい」に
	var j: Dictionary = of_type(reply(sim, 0, ticks, [3, 3, 3, 3]), "judge")[0]
	eq(j["pos"], [0, 2, 4, 5], "お手本の位置")
	eq(j["keys"], [3, 3, 3, 3], "お手本のキー")
	eq(j["presses"].size(), 4, "押した記録")
	eq(int(j["presses"][1][0]), ticks[1], "押した tick")
	eq(int(j["points"]), sim.points, "入った点(1 回目なので合計と同じ)")
	return true
