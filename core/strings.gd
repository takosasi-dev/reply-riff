# 文言(INV-7・画面設計書 §6)。画面に出す文字はすべてここに置く。
# 文言を足したら tools/subset_font.py を回し直す(同梱の字体はここの文字に絞ってある)。
extends RefCounted

const NAME := "ReplyRiff"
const VERSION := "v0.1.0"
const URL := "https://takosasi-dev.github.io/reply-riff/"

# 鍵盤(§9.1。左から 0〜7)
const KEYS := ["A", "S", "D", "F", "J", "K", "L", ";"]
const NOTE_NAMES := ["ド", "レ", "ミ", "ソ", "ラ", "ド", "レ", "ミ"]

# S0
const S0_START := "クリックかキーで始める"
const S0_KEYBOARD := "キーボードで遊ぶゲーム"
const TOUCH := "このゲームはキーボードで遊ぶ。PC で開いてほしい"
const IME := "日本語入力を切って(半角英数で)遊んでほしい"

# S1
const TAGLINE := "聞いて、同じように弾き返す"
const B_DAILY := "今日の曲"
const B_PRACTICE := "練習(毎回ちがうフレーズ)"
const B_SETTINGS := "設定"
const REC_FIRST := "1回目 %s点"
const REC_TODAY_BEST := "今日の最高 %s点"
const REC_BEST := "最高 %s点"
const REC_NONE := "まだ遊んでいない"
const SOUND_NOTE := "音を出して遊んでほしい"
const LOAD_FAILED := "保存を読めなかったので、記録を初めからにした"

# S2
const ESC := "Esc"
const BAR_TURN := "回 %d/8"
const BAR_SONG := "自分の曲"
const BAR_POINTS := "%s点"
const HEAD_CALL := "お手本を聞く"
const HEAD_REPLY := "弾き返す"
const HEAD_SONG := "自分の曲"
const TURN_OK := "合った"
const TURN_MISS := "外れ"
const LAYER_NAMES := ["ドラム", "ベース", "和音", "パッド"]
const SKIP := "Enter で飛ばす"
const OVER_DONE := "曲ができた"
const OVER_STOP := "曲が止まった"

# S3
const RES_DONE := "曲ができた(外れ %d 回)"
const RES_STOP := "%d 回目で曲が止まった"
const RES_POINTS := "%s点"
const RES_NEW_BEST := "最高 +%s(新しい記録)"
const RES_TO_BEST := "最高まで −%s"
const RES_TODAY_BEST := "(今日の最高 %s点)"
const RES_TURNS := "合った回 %d/8"
const RES_LIVES := "残機 %d"
const GRADE_NAMES := ["ぴったり", "よい", "おしい", "外れ"]
const RES_GRADE := "%s %d"
const B_RETRY := "もう1回"
const B_COPY := "コピー"
const B_TITLE := "タイトルへ"
const COPIED := "コピーを試した。貼れない時は枠から写す"
const SAVE_FAILED := "このブラウザでは記録を残せない"

# 共有する文字(§9.11)
const MODE_LABEL := ["今日の曲", "練習"]
const DAILY_FIRST := "今日の曲・1回目"
const SHARE_HEAD := "%s %s(%s)"
const SHARE_DONE := "8 小節"
const SHARE_STOP := "%d 回目で止まった"
const SHARE_BODY := "%s / 外れ %d 回 / ぴったり %d / %s点"

# S4
const SETTINGS := "設定"
const SET_VOLUME := "音量"
const SET_SHAKE := "画面の揺れ"
const SET_FLASH := "点滅を弱める"
const ON := "入"
const OFF := "切"
const B_BACK := "戻る"

# S5
const PAUSE := "一時停止"
const B_RESUME := "続ける"
const B_RESTART := "やり直す"

# キーの確かめ(共通 §3 の 22。?keys=1 の時だけ。Esc 2 回でタイトルへ)
const KEYS_TITLE := "キーの確かめ(Esc 2 回でタイトルへ)"
const KEY_DETAIL := "physical_keycode %d (%s) / key_label %s / unicode %d / pressed %s / echo %s / ctrl %s alt %s meta %s shift %s"
