# 調整値(仕様書 §9.8・INV-7)。時間は tick(1/120 秒)の整数で持つ。
# 演出の時間(ms)・音の大きさ・設定の段もここに置く。ほかのファイルに数値の調整値を書かない。
extends RefCounted

const TICK_HZ := 120
const MAX_STEPS_PER_FRAME := 16
const BEHIND_PAUSE_MS := 1000  # E-8: 目標から 16 tick を超えて遅れたままこれだけ続いたら一時停止
const STALL_MS := 500  # 伴奏を鳴らしているのに再生の位置がこれだけ動かなければ、フレームの時間で進める(E-11 の保険)

# 100 BPM(§9.1)
const BEAT_TICKS := 72
const EIGHTH_TICKS := 36
const BAR_TICKS := 288
const BAR_EIGHTHS := 8
const KEYS_N := 8  # A S D F J K L ;

# 曲の時間割(§9.2)
const TURNS := 8
const SONG_TICKS := 7200
const SONG_START := 4896  # 数え 1 小節 + 8 回 × 2 小節
const LOOP_BARS := 4  # 伴奏の C・Am・F・G

# 判定(§9.6)
const FIRST_MS := 180
const PERFECT_MS := 45
const GOOD_MS := 90
const OK_MS := 150
const JUDGE_DELAY := 40

# 残機と層(§9.3・§9.4)
const LIVES := 3
const MAX_LAYERS := 4

# 点(§9.7)
const NOTE_POINTS := [300, 200, 100, 0]  # ぴったり・よい・おしい・外れ
const TURN_BONUS := 500
const PERFECT_BONUS := 300
# 段位の区切りの点(v0.3.1。仕様書 §9.8)。仮の値: bot の点の分布から決めた。人が遊んで決め直す。
# 名前は strings.gd の RANK_NAMES(この配列より 1 つ多い)
const RANK_POINTS := [3000, 8000, 12500, 16500]

# 回の表(§9.5。INV-6 で中身を変えない)。keys はキーの番号(A S D F J K L ; = 0〜7)
const TURN_TABLE := [
	{"keys": [3], "n": 4, "fixed": [0, 2, 4, 5], "even": false, "odd_first": false, "hint": 2},
	{"keys": [3, 4], "n": 4, "fixed": [], "even": true, "odd_first": false, "hint": 2},
	{"keys": [2, 3, 4], "n": 4, "fixed": [], "even": false, "odd_first": false, "hint": 2},
	{"keys": [1, 2, 3, 4, 5], "n": 5, "fixed": [], "even": false, "odd_first": false, "hint": 2},
	{"keys": [1, 2, 3, 4, 5], "n": 5, "fixed": [], "even": false, "odd_first": true, "hint": 1},
	{"keys": [0, 1, 2, 3, 4, 5, 6, 7], "n": 5, "fixed": [], "even": false, "odd_first": false, "hint": 1},
	{"keys": [0, 1, 2, 3, 4, 5, 6, 7], "n": 6, "fixed": [], "even": false, "odd_first": true, "hint": 0},
	{"keys": [0, 1, 2, 3, 4, 5, 6, 7], "n": 6, "fixed": [], "even": false, "odd_first": false, "hint": 0},
]  # hint: 2 = 全部の音で光る、1 = 1 音目だけ、0 = 無し
const KEY_STEP := 2  # 2 音目からのキーは、前の音の使うキーの中の順番 ±2 以内

# 日替わりの種(共通 §3 の 13)
const DAY_SEED_MUL := 2654435761
const DAY_SALT := 0x5252
const EPOCH_YEAR := 2026

# テスト用の bot(§9.13)
const BOT_SEED := 0x2468

# 設定(共通 §3 の 17)
const VOLUMES := [0, 25, 50, 75, 100]
const DEFAULT_VOLUME := 75
const SAMPLE_KEY := 3  # 音量を選んだ時に鳴らす音(ソ)
const CONFIRM_KEY := 5  # ボタンを決めた時に薄く鳴らす音(高いド。v0.3.0)

# 音(§9.9・§9.10)
const LOOP_SEC := 9.6  # 伴奏のくり返し(4 小節)
const DIM_DB := -12.0  # 薄い音(外れた回のお手本)
const LAYER_OFF_DB := -80.0
const AUDIO_BUDGET := 3 * 1024 * 1024  # 書き出しに入る音の合計(バイト)

# 演出(§9.12・画面設計書 §8)。ms と px
const SHAKE_PX := 4.0
const SHAKE_MS := 100
const KEY_SINK_PX := 4.0
const KEY_SINK_MS := 80
const KEY_LIT_MS := 300  # 手がかりの光と、自分の曲の光
const BEAT_LIT_MS := 150
const HEAD_FADE_MS := 200
const TAG_LIT_MS := 600
const RESULT_MS := 1200  # 見出しの下の「合った」「外れ」
const OVER_MS := 600
const COUNT_MS := 600
const RETRY_LOCK_MS := 300
const IME_NOTE_MS := 3000
const REDUCED_FLASH_ALPHA := 0.2
# 磨きで足した手がかり(2026-11-20)
const TAG_POP_MS := 400  # 増えた層の札が、鳴り始めた小節の頭で膨らむ
const TAG_POP_PX := 6.0
const LIFE_LOST_MS := 500  # 残機を失った丸から赤い輪が広がる
const GAIN_MS := 900  # 判定で入った点が浮かんで消える
const OLD_MARK_ALPHA := 0.5  # 次のお手本の間に残す、前の回の段の印の濃さ
# UI の作り直しで足した動き(2026-11-21、v0.3.0。画面設計書 §10)
const TRANS_OUT_MS := 120  # 画面の切り替わり: 前の画面を暗くする
const TRANS_IN_MS := 220  # 新しい画面をスポットの輪で開く
const TRANS_PLAY_OUT_MS := 80  # プレイに入る時は短く(もう1回を遅くしない)
const TRANS_PLAY_IN_MS := 160
const PAUSE_FADE_MS := 150
const POINTS_ROLL_MS := 300  # 上の帯の点が数え上がる
const POINTS_BUMP_MS := 240  # 点が増えた時に跳ねる
const POINTS_BUMP := 0.22
const TALLY_STEP_MS := 80  # 結果: 合った回のレコードを 1 枚ずつ置く間
const CONFETTI_MS := 1800  # 結果: 新しい記録の紙吹雪
const RANK_DROP_MS := 260  # 結果(v0.3.1): 点が数え上がった後、段位の看板が吊り下がって揺れが止まるまで
const RANK_BULB_MS := 70  # その後、看板の電球を 1 つずつ灯す間

# 画面の配置(画面設計書 §3)
const RULER_X0 := 240.0
const RULER_X1 := 1040.0
const RULER_Y := 200.0
const KEY_W := 104.0
const KEY_H := 140.0
const KEY_GAP := 16.0
const HAND_GAP := 96.0
const KEY_Y := 480.0
const ROW_DY := 40.0  # 目盛りの下の 1 段目(お手本の ◆・押した位置の丸)
const ROW_GRADE_DY := 92.0  # 2 段目(段の印。その下にお手本のキー)
const DOT_R := 13.0  # 押した位置の丸
const PIPS_Y := 668.0  # 回の進み(8 つの印)
const PIP_GAP := 36.0
