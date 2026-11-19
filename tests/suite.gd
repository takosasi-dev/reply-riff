# テストの土台。ok / eq で確かめ、失敗は errors にたまる。曲を bot や押した記録で最後まで回す道具も持つ。
# 各テストは最後に true を返す(途中で止まったことを見分けるため)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const TL := preload("res://core/timeline.gd")
const J := preload("res://core/judge.gd")
const Sim := preload("res://core/sim.gd")
const Bots := preload("res://core/bots.gd")

var errors: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


static func run(sim: Sim, ticks: int) -> Array:
	var ev: Array = []
	for k in ticks:
		if sim.is_over():
			break
		sim.step()
		ev.append_array(sim.events())
	return ev


# tick まで進める(その tick の step はまだ)。
static func run_to(sim: Sim, at: int) -> Array:
	return run(sim, at - sim.tick)


static func of_type(ev: Array, t: String) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e["type"] == t)


# bot で最後まで回す。{ sim, events, log([[tick, キー], ...]) }
static func play_bot(seed_value: int, kind: int, arg: int = 0) -> Dictionary:
	var sim := Sim.new(seed_value, Sim.MODE_DAILY)
	var bot := Bots.new(kind, arg)
	var ev: Array = []
	var log: Array = []
	while not sim.is_over():
		var before: int = sim._queue.size()
		bot.act(sim)
		for k in range(before, sim._queue.size()):
			log.append([sim.tick, sim._queue[k]])
		sim.step()
		ev.append_array(sim.events())
	return {"sim": sim, "events": ev, "log": log}


# 押した記録どおりに押して最後まで回す。
static func replay(seed_value: int, log: Array) -> Sim:
	var sim := Sim.new(seed_value, Sim.MODE_DAILY)
	var k := 0
	while not sim.is_over():
		while k < log.size() and int(log[k][0]) == sim.tick:
			sim.queue_press(log[k][1])
			k += 1
		sim.step()
	return sim


# 回 t の返しを、音ごとの押す tick(返しの頭からの差ではなく絶対の tick)とキーで押し、判定まで進める。判定の events を返す。
static func reply(sim: Sim, t: int, ticks: Array, keys: Array) -> Array:
	var ev: Array = []
	for i in ticks.size():
		ev.append_array(run_to(sim, ticks[i]))
		sim.queue_press(keys[i])
	ev.append_array(run_to(sim, J.judge_tick(t, sim.phrase[t]) + 1))
	return ev


# 回 t のお手本どおりの tick(+ off)。
static func model_ticks(sim: Sim, t: int, off: int = 0) -> Array:
	var turn: Dictionary = sim.phrase[t]
	var out: Array = []
	for i in turn["pos"].size():
		out.append(J.note_tick(t, turn, i) + off)
	return out
