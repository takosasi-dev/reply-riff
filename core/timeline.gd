# 曲の時間割(仕様書 §9.2)。tick から区間と回を出す。整数だけで数える。
# 数え 1 小節 → 回 t のお手本と返し(各 1 小節)× 8 → 自分の曲 8 小節 → 7200 で終わり。
extends RefCounted

const B := preload("res://core/balance.gd")

const COUNT := 0
const CALL := 1
const REPLY := 2
const SONG := 3
const END := 4


# 回 t(0〜7)のお手本の頭 C(t)。
static func call_start(t: int) -> int:
	return B.BAR_TICKS + 2 * B.BAR_TICKS * t


# 回 t の返しの頭 R(t)。
static func reply_start(t: int) -> int:
	return call_start(t) + B.BAR_TICKS


@warning_ignore("integer_division")
static func section(tick: int) -> int:
	if tick < B.BAR_TICKS:
		return COUNT
	if tick < B.SONG_START:
		return CALL if ((tick - B.BAR_TICKS) / B.BAR_TICKS) % 2 == 0 else REPLY
	if tick < B.SONG_TICKS:
		return SONG
	return END


# お手本か返しの間なら回(0〜7)、ほかは -1。
@warning_ignore("integer_division")
static func turn_of(tick: int) -> int:
	var s := section(tick)
	if s != CALL and s != REPLY:
		return -1
	return (tick - B.BAR_TICKS) / (2 * B.BAR_TICKS)
