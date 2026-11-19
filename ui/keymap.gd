# 物理キーを鍵盤の番号(0〜7)へ直す(仕様書 FR-2・§9.1)。配列の印字が違っても位置で決まる(physical_keycode)。
# G と H は使わない(D-1)。押しっぱなしの繰り返しと Ctrl・Alt・Meta と一緒の「押す」を捨てるのは ui/play.gd(FR-24)。
extends RefCounted

const KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON]


# 鍵盤の 8 キーなら 0〜7、ほかは -1(E-1)。
static func index_of(ev: InputEventKey) -> int:
	return KEYS.find(ev.physical_keycode)


static func has_modifier(ev: InputEventKey) -> bool:
	return ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed
