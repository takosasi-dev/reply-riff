"""音を合成して assets/audio/ に書く(仕様書 §9.10)。標準ライブラリだけ・乱数は自前の式(何度回しても同じバイト列。NFR-16)。
16bit PCM・モノラル・22050 Hz。外の素材は使わない。

- note_0〜7.wav  8 つの音(C4 D4 E4 G4 A4 C5 D5 E5)。はじく音、0.6 秒で消える
- layer_1〜4.wav  伴奏の 4 層(ドラム・ベース・和音・パッド)。100 BPM・4 小節(C・Am・F・G)= 9.6 秒で、頭と尻がつながる
- mix/mix_0〜4.wav  層 0〜n を足した物(R-4 に当たった時の控え。.gdignore で取り込まず、書き出しにも入らない)
- click.wav(数えの音・メニュー)・miss.wav(外れの低い短い音)・over.wav(終わりの和音)

    python tools/gen_audio.py
"""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050
TAU = 2 * math.pi
BEAT = 0.6  # 100 BPM
LOOP = int(16 * BEAT * RATE)  # 4 小節 = 9.6 秒
NOTES = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.26]
# 小節ごとの和音(C・Am・F・G)。根音(ベース)と 3 和音
CHORDS = [
    (130.81, [261.63, 329.63, 392.00]),
    (110.00, [220.00, 261.63, 329.63]),
    (87.31, [174.61, 220.00, 261.63]),
    (98.00, [196.00, 246.94, 293.66]),
]


def add(buf, at, dur, fn, wrap=False):
    """buf の at 秒から dur 秒ぶん、fn(t) を足す。wrap なら尻からはみ出た分を頭へ回す(くり返しの継ぎ目を消す)。"""
    start = int(at * RATE)
    n = int(dur * RATE)
    if not wrap:
        while len(buf) < start + n:
            buf.append(0.0)
    for i in range(n):
        k = start + i
        buf[k % len(buf) if wrap else k] += fn(i / RATE)


def pluck(f, decay=6.0, length=0.6):
    """はじく音: 倍音 3 本(高い倍音ほど早く消える)。最後の 30 ms で 0 へ。"""
    def fn(t):
        e = math.exp(-decay * t) * min(1.0, t / 0.003, (length - t) / 0.03)
        return e * (math.sin(TAU * f * t) + 0.5 * math.exp(-4 * t) * math.sin(TAU * 2 * f * t) + 0.2 * math.exp(-8 * t) * math.sin(TAU * 3 * f * t))
    return fn


def write(path, buf, peak):
    top = max(abs(x) for x in buf) or 1.0
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / top * peak * 32767)) for x in buf))


def noise():
    """決まった並びの雑音(32 bit の線形合同法)。"""
    state = [12345]

    def nxt():
        state[0] = (state[0] * 1103515245 + 12345) & 0xFFFFFFFF
        return state[0] / 2147483648.0 - 1.0
    return nxt


def drums():
    buf = [0.0] * LOOP
    for b in range(16):
        # バスドラム: 120 → 45 Hz に下がる正弦波
        def kick(t):
            return math.exp(-14 * t) * math.sin(TAU * (45 * t + 75 * (1 - math.exp(-30 * t)) / 30))
        add(buf, b * BEAT, 0.3, kick, wrap=True)
    nz = noise()
    for e in range(32):
        if e % 2 == 1:  # 裏拍のハイハット
            prev = [0.0]

            def hat(t):
                x = nz()
                y = x - prev[0]  # 差を取って高い音だけにする
                prev[0] = x
                return 0.35 * math.exp(-60 * t) * y
            add(buf, e * BEAT / 2, 0.08, hat, wrap=True)
    return buf


def bass():
    buf = [0.0] * LOOP
    for bar, (root, _) in enumerate(CHORDS):
        for q in range(4):
            def fn(t, f=root):
                e = math.exp(-3 * t) * min(1.0, t / 0.005, (0.55 - t) / 0.03)
                return e * (math.sin(TAU * f * t) + 0.3 * math.sin(TAU * 2 * f * t))
            add(buf, (bar * 4 + q) * BEAT, 0.55, fn, wrap=True)
    return buf


def chord():
    buf = [0.0] * LOOP
    for bar, (_, tri) in enumerate(CHORDS):
        for e in range(8):
            if e % 2 == 1:  # 裏拍の刻み
                for f in tri:
                    def fn(t, f=f):
                        env = math.exp(-12 * t) * min(1.0, t / 0.004, (0.2 - t) / 0.02)
                        return env * (math.sin(TAU * f * t) + 0.25 * math.sin(TAU * 3 * f * t))
                    add(buf, bar * 4 * BEAT + e * BEAT / 2, 0.2, fn, wrap=True)
    return buf


def pad():
    buf = [0.0] * LOOP
    bar_sec = 4 * BEAT
    for bar, (_, tri) in enumerate(CHORDS):
        for f in tri:
            def fn(t, f=f / 2):
                env = min(1.0, t / 0.35) * min(1.0, (bar_sec + 0.3 - t) / 0.4)
                return env * (math.sin(TAU * f * t) + math.sin(TAU * f * 1.006 * t) + 0.3 * math.sin(TAU * 2 * f * t))
            add(buf, bar * bar_sec, bar_sec + 0.3, fn, wrap=True)
    return buf


LAYERS = [("drums", drums, 0.42), ("bass", bass, 0.32), ("chord", chord, 0.2), ("pad", pad, 0.16)]


def main():
    for k, f in enumerate(NOTES):
        b = []
        add(b, 0, 0.6, pluck(f))
        write(OUT / f"note_{k}.wav", b, 0.5)
    layers = []
    for k, (name, make, peak) in enumerate(LAYERS):
        b = make()
        top = max(abs(x) for x in b)
        layers.append([x / top * peak for x in b])
        write(OUT / f"layer_{k + 1}.wav", b, peak)
    for n in range(5):
        mixed = [sum(l[i] for l in layers[:n]) for i in range(LOOP)]
        path = OUT / "mix" / f"mix_{n}.wav"
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), "wb") as w:  # 足した大きさのまま書く(層ごとの釣り合いを変えない)
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(x * 32767)))) for x in mixed))
    (OUT / "mix" / ".gdignore").write_text("", encoding="utf-8")
    b = []
    add(b, 0, 0.05, lambda t: math.exp(-80 * t) * math.sin(TAU * 1500 * t))
    write(OUT / "click.wav", b, 0.35)
    b = []
    add(b, 0, 0.25, lambda t: math.exp(-10 * t) * (math.sin(TAU * 110 * t) + math.sin(TAU * 330 * t) / 3 + math.sin(TAU * 550 * t) / 5))
    write(OUT / "miss.wav", b, 0.5)
    b = []
    for k, f in enumerate([261.63, 329.63, 392.00, 523.25]):
        add(b, k * 0.05, 1.4, pluck(f, decay=2.5, length=1.4))
    write(OUT / "over.wav", b, 0.55)
    files = sorted(OUT.rglob("*.wav"))
    shipped = [p for p in files if p.parent.name != "mix"]
    print(f"{len(files)} 個(書き出しに入るのは {len(shipped)} 個、取り込み前 {sum(p.stat().st_size for p in shipped):,} バイト)")


if __name__ == "__main__":
    main()
