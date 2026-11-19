# テスト用の bot(仕様書 §9.13)。お手本どおりのキーを、m(i) に(ずれ bot は + c、揺れ bot は ± j の範囲で)押す。
# step の前に act(sim) を呼ぶと、その tick に押す予定のキーを sim.queue_press へ渡す。揺れは bot 用の rng で決める。
extends RefCounted

const B := preload("res://core/balance.gd")
const J := preload("res://core/judge.gd")
const Rng := preload("res://core/rng.gd")

const EXACT := 0
const SHIFT := 1
const JITTER := 2
const IDLE := 3

var kind := EXACT
var arg := 0  # ずれ bot の c、揺れ bot の j(tick)
var _rng: Rng
var _plan: Dictionary = {}  # tick → [キー, ...]
var _built := false


func _init(p_kind: int, p_arg: int = 0, p_seed: int = B.BOT_SEED) -> void:
	kind = p_kind
	arg = p_arg
	_rng = Rng.new(p_seed)


func act(sim: RefCounted) -> void:
	if not _built:
		_build(sim.phrase)
	for k: int in _plan.get(sim.tick, []):
		sim.queue_press(k)


func _build(phrase: Array) -> void:
	_built = true
	if kind == IDLE:
		return
	for t in phrase.size():
		var turn: Dictionary = phrase[t]
		for i in turn["pos"].size():
			var off := 0
			if kind == SHIFT:
				off = arg
			elif kind == JITTER:
				off = _rng.next_int(2 * arg + 1) - arg
			var at := J.note_tick(t, turn, i) + off
			if not _plan.has(at):
				_plan[at] = []
			_plan[at].append(turn["keys"][i])
