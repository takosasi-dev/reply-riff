# 1 曲の全状態と step()(仕様書 §9.3)。入力はキーの番号 0〜7 の「押す」だけ(INV-5)。
# 時間割・フレーズ・判定・点・層・残機・自分の曲の音はここで決める。ui と audio は events() と snapshot() を読むだけ(INV-1)。
# 1 つの回は 1 度しか判定しない(rewind_to_turn() で判定済みの返しの小節へ戻っても、層・残機・点は二重に動かない)。
extends RefCounted

const B := preload("res://core/balance.gd")
const TL := preload("res://core/timeline.gd")
const Phrase := preload("res://core/phrase.gd")
const J := preload("res://core/judge.gd")
const Score := preload("res://core/score.gd")

const MODE_DAILY := 0
const MODE_PRACTICE := 1

var seed_value := 1
var mode := 0
var tick := 0
var phrase: Array = []  # 8 回ぶん(phrase.gd)
var presses: Array = []  # 回ごとの、受け付けの間に押した [tick, キー]
var judged := 0  # 判定を終えた回の数(次に判定する回)
var turn_grades: Array = []  # 判定した回ごとの、音ごとの段
var turn_ok: Array = []  # 判定した回ごとの、合ったか
var lives := B.LIVES
var layers := 0
var points := 0
var over := false
var over_reason := ""  # "end" = 曲の終わり、"lives" = 残機 0
var song: Dictionary = {}  # 自分の曲の tick → [[キー, 自分の音か], ...]

var _queue: Array = []
var _events: Array = []


func _init(p_seed: int, p_mode: int) -> void:
	seed_value = p_seed
	mode = p_mode
	phrase = Phrase.build(p_seed)
	for t in B.TURNS:
		presses.append([])


func queue_press(k: int) -> void:
	if k >= 0 and k < B.KEYS_N:
		_queue.append(k)


func events() -> Array:
	return _events


func is_over() -> bool:
	return over


@warning_ignore("integer_division")
func step() -> void:
	_events = []
	if over:
		return
	# 2. 押すを来た順に記録する。受け付けの間の物だけを判定に使う
	for k: int in _queue:
		if judged < B.TURNS and J.in_window(judged, phrase[judged], tick):
			presses[judged].append([tick, k])
	_queue.clear()
	# 3. 拍と、お手本の音
	if tick % B.BEAT_TICKS == 0:
		_events.append({"type": "beat", "beat": (tick / B.BEAT_TICKS) % 4})
	if TL.section(tick) == TL.CALL:
		var t := TL.turn_of(tick)
		var turn: Dictionary = phrase[t]
		for i in turn["pos"].size():
			if TL.call_start(t) + int(turn["pos"][i]) * B.EIGHTH_TICKS == tick:
				_events.append({"type": "call_note", "key": turn["keys"][i], "lit": Phrase.lit(turn, i), "turn": t, "i": i, "pos": turn["pos"][i]})
	# 4. 判定(自分の曲の音より先。E-6)
	if judged < B.TURNS and tick == J.judge_tick(judged, phrase[judged]):
		_judge(judged)
		if over:
			return
	# 5. 自分の曲の音
	if TL.section(tick) == TL.SONG:
		for n: Array in song.get(tick, []):
			_events.append({"type": "song_note", "key": n[0], "own": n[1]})
	# 6. 進める
	tick += 1
	if tick >= B.SONG_TICKS:
		_finish("end")


func _judge(t: int) -> void:
	var turn: Dictionary = phrase[t]
	var g := J.grades(t, turn, presses[t])
	var ok := not g.has(J.MISS)
	turn_grades.append(g)
	turn_ok.append(ok)
	var gained := Score.turn_points(g, turn["pos"].size())
	points += gained
	judged = t + 1
	_events.append({"type": "judge", "turn": t, "grades": g, "pos": turn["pos"].duplicate(), "keys": turn["keys"].duplicate(),
		"presses": presses[t].duplicate(true), "points": gained})  # pos 以降は画面の手がかり(お手本と押した位置を比べる)
	# 自分の曲のこの回の小節: 合えば押した音と位置で、外れならお手本を薄い音で
	var bar := B.SONG_START + B.BAR_TICKS * t
	if ok:
		for p: Array in presses[t]:
			_add_song(bar + maxi(int(p[0]) - TL.reply_start(t), 0), p[1], true)
	else:
		for i in turn["pos"].size():
			_add_song(bar + int(turn["pos"][i]) * B.EIGHTH_TICKS, turn["keys"][i], false)
	if ok:
		layers = mini(layers + 1, B.MAX_LAYERS)
		_events.append({"type": "turn_ok", "turn": t, "layers": layers})
	else:
		lives -= 1
		_events.append({"type": "turn_miss", "turn": t, "lives": lives})
		if lives <= 0:
			_finish("lives")


func _add_song(at: int, k: int, own: bool) -> void:
	if not song.has(at):
		song[at] = []
	song[at].append([k, own])


func _finish(reason: String) -> void:
	over = true
	over_reason = reason
	_events.append({"type": "over", "reason": reason})


# 一時停止から戻る時(D-13)。今の回(まだ判定していない回)の押した記録を消し、そのお手本の 1 小節前へ戻す(回 0 は 0)。
# 8 回とも判定した後(自分の曲の間)は、今の小節の頭へ戻す。
func rewind_to_turn() -> void:
	if over:
		return
	_queue.clear()
	_events = []
	if judged >= B.TURNS:
		tick -= tick % B.BAR_TICKS
		return
	presses[judged].clear()
	tick = 0 if judged == 0 else TL.call_start(judged) - B.BAR_TICKS


func snapshot() -> Dictionary:
	var sec := TL.section(tick)
	var t := TL.turn_of(tick)
	var lit: Array = []  # 手がかりで光らせるキー(鳴っている 8 分音符の間)
	var call_pos: Array = []  # お手本の間に、もう鳴った音の位置(◆)
	if sec == TL.CALL:
		var turn: Dictionary = phrase[t]
		for i in turn["pos"].size():
			var at := TL.call_start(t) + int(turn["pos"][i]) * B.EIGHTH_TICKS
			if at <= tick:
				call_pos.append(turn["pos"][i])
				if tick < at + B.EIGHTH_TICKS and Phrase.lit(turn, i):
					lit.append(turn["keys"][i])
	# 判定の印: 最後に判定した回の音ごとの段。次の回のお手本が始まるまで
	var marks: Array = []
	if judged > 0 and (judged >= B.TURNS or tick < TL.call_start(judged)):
		var jt := judged - 1
		var pos: Array = phrase[jt]["pos"]
		for i in pos.size():
			marks.append([pos[i], turn_grades[jt][i]])
	return {"tick": tick, "section": sec, "turn": t, "lit": lit, "call_pos": call_pos, "marks": marks,
		"presses": presses[judged].duplicate() if judged < B.TURNS else [], "lives": lives, "layers": layers, "points": points,
		"judged": judged, "over": over}


func result() -> Dictionary:
	var counts := [0, 0, 0, 0]
	for g: Array in turn_grades:
		for x: int in g:
			counts[x] += 1
	var ok_n := turn_ok.count(true)
	return {"points": points, "turns_ok": ok_n, "reached": judged, "missed_turns": judged - ok_n, "counts": counts,
		"lives": lives, "finished": judged >= B.TURNS and lives > 0}
