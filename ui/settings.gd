# S4 設定(共通 §6・画面設計書 §5・§10)。音量(5 段)・画面の揺れ・点滅を弱める。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。
# ← → でも値を変えられる。Esc か「戻る」で来た画面へ。作りは KeyFlak の ui/settings.gd(キーの確かめは ?keys=1 の画面に分けた)。
# v0.3.0: 行は左に項目名、右に今の値(音量は 5 本の棒と数、入・切はスイッチと字)。下に操作の案内。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")


# 行の右の値の絵。level は音量の段(0〜4)か -1、on は入・切。
class Val extends Control:
	const Kit := preload("res://ui/kit.gd")
	var level := -1
	var on := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var mid := size.y / 2
		if level >= 0:
			for k in 5:
				var h := 10.0 + 6.0 * k
				var r := Rect2(k * 16.0, mid + 16 - h, 10, h)
				if k <= level and level > 0:
					draw_rect(r, Kit.C_TEXT)
				else:
					draw_rect(r, Kit.C_EDGE, false, 2.0)
			return
		var track := Rect2(0, mid - 15, 64, 30)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(15)
		sb.bg_color = Kit.C_CRIMSON if on else Kit.C_FLOOR
		sb.border_color = Kit.C_TEXT if on else Kit.C_EDGE
		sb.set_border_width_all(2)
		sb.anti_aliasing = true
		draw_style_box(sb, track)
		draw_circle(Vector2(49 if on else 15, mid), 10, Kit.C_TEXT if on else Kit.C_DIM)


var menu: Menu
var store: RefCounted
var _vol: Button
var _shake: Button
var _flash: Button
var _vals := {}  # ボタン → [値の字, 値の絵]


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(1280, 720)
	add_child(Kit.place(Kit.label(S.SETTINGS, 40, Kit.C_TEXT, 800, 6), 0, 64, 1280, 60))
	_vol = _row("volume", S.SET_VOLUME, 170)
	_shake = _row("shake", S.SET_SHAKE, 258)
	_flash = _row("reduce_flash", S.SET_FLASH, 346)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 26), 520, 466, 240, 72)
	add_child(ret)
	add_child(Kit.place(Kit.label(S.SET_HINT, 18, Kit.C_DIM, 500), 0, 600, 1280, 32))
	_vol.pressed.connect(func() -> void: _step_volume(1))
	_shake.pressed.connect(func() -> void: _toggle("shake"))
	_flash.pressed.connect(func() -> void: _toggle("reduce_flash"))
	ret.pressed.connect(func() -> void: back.emit())
	menu = Menu.new([_vol, _shake, _flash, ret] as Array[Button], 0, [0])
	_paint()


# 1 行: ボタン(字は子のラベル)。左に項目名、右に値の字と絵。
func _row(node_name: String, text: String, y: float) -> Button:
	var b := Kit.place(Kit.button(node_name, "", 26), 340, y, 600, 72)
	var name_l := Kit.label(text, 26, Kit.C_TEXT, 700)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_child(Kit.place(name_l, 64, 0, 300, 72))
	var val_l := Kit.label("", 26, Kit.C_TEXT, 700)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(Kit.place(val_l, 380, 0, 80, 72))
	var v := Val.new()
	b.add_child(Kit.place(v, 480, 0, 90, 72))
	_vals[b] = [val_l, v]
	add_child(b)
	return b


func _paint() -> void:
	var st: Dictionary = store.settings()
	_vals[_vol][0].text = str(int(st["volume"]))
	_vals[_vol][1].level = B.VOLUMES.find(int(st["volume"]))
	for pair: Array in [[_shake, st["shake"]], [_flash, st["reduce_flash"]]]:
		_vals[pair[0]][0].text = S.ON if pair[1] else S.OFF
		_vals[pair[0]][1].on = pair[1]
	for b: Button in _vals:
		_vals[b][1].queue_redraw()


func _step_volume(d: int) -> void:
	var i: int = B.VOLUMES.find(int(store.settings()["volume"]))
	var v: int = B.VOLUMES[(i + d + B.VOLUMES.size()) % B.VOLUMES.size()]
	store.set_setting("volume", v)
	Notes.set_volume(v)
	Notes.play_key(B.SAMPLE_KEY)
	_paint()


func _toggle(k: String) -> void:
	store.set_setting(k, not store.settings()[k])
	if k == "reduce_flash":
		Kit.calm = store.settings()[k]  # 動きを減らすのは、この画面からすぐ効かせる
	_paint()


func key(ev: InputEventKey) -> void:
	if not ev.pressed or ev.echo:
		return
	if ev.physical_keycode == KEY_ESCAPE:
		back.emit()
	elif menu.sel == 0 and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_step_volume(-1 if ev.physical_keycode == KEY_LEFT else 1)
	elif menu.sel in [1, 2] and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_toggle(["", "shake", "reduce_flash"][menu.sel])
		Notes.play("click")
	else:
		menu.key(ev)
