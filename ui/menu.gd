# キーボードでボタンを選ぶ(共通 §3 の 18)。↑↓ で選び、Enter か Space で押す。マウスでも押せる。
# 押した時の動きはボタンの pressed に繋いでおく。選ぶ音は click、決める音は薄い高いド(v0.3.0)。
# quiet の番号のボタンは決める音を鳴らさない(設定の音量のように、押すと自分の音を鳴らす物)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

var buttons: Array[Button] = []
var sel := 0


func _init(list: Array[Button], first: int = 0, quiet: Array = []) -> void:
	buttons = list
	sel = clampi(first, 0, maxi(buttons.size() - 1, 0))
	for i in buttons.size():
		var b := buttons[i]
		b.mouse_entered.connect(func() -> void: select(buttons.find(b)))
		if not quiet.has(i):
			b.pressed.connect(func() -> void: Notes.play_key(B.CONFIRM_KEY, true))
	_paint()


func select(i: int) -> void:
	if i < 0 or i >= buttons.size():
		return
	sel = i
	_paint()


func _paint() -> void:
	for k in buttons.size():
		Kit.set_selected(buttons[k], k == sel)


# キーを受ける。使ったら真。
func key(ev: InputEventKey) -> bool:
	if not ev.pressed or ev.echo or buttons.is_empty():
		return false
	match ev.physical_keycode:
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var b := buttons[sel]
			if not b.disabled:
				b.pressed.emit()
		_:
			return false
	return true


func _move(d: int) -> void:
	select((sel + d + buttons.size()) % buttons.size())
	Notes.play("click")
