# このゲームの音（効果音・BGM・雨の音）をコードで作るスクリプト。素材は使っていない＝全部オリジナル。
# 使い方: uv run --no-project python tools/make_sounds.py   → sfx/*.wav, bgm/*.wav
# 音は「音の高さ（周波数）× 長さ × 波の形 × 音量の変化（エンベロープ）」の組み合わせ。
# BGM は「オルゴールの音」を楽譜（音の名前と長さ）どおりに並べて作る。曲を直したいときは MELODY / CHORDS を書きかえる。
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parent.parent
random.seed(7)

NOTE_INDEX = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def freq(name):
    """'C5' 'F#4' 'Bb3' → 周波数（A4=440Hz）"""
    base, rest = name[0], name[1:]
    shift = 0
    while rest and rest[0] in "#b":
        shift += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    n = NOTE_INDEX[base] + shift + (int(rest) - 4) * 12
    return 440.0 * 2 ** (n / 12)


def save(path, samples, peak=0.7):
    m = max(1e-9, max(abs(s) for s in samples))
    k = peak / m
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))


def buf(sec):
    return [0.0] * int(RATE * sec)


def add(dst, src, at_sec, vol=1.0, wrap=False):
    o = int(at_sec * RATE)
    n = len(dst)
    for i, s in enumerate(src):
        j = o + i
        if j >= n:
            if not wrap:
                break
            j %= n  # ループの最後からはみ出した響きは、頭に重ねる（つなぎ目が自然になる）
        dst[j] += s * vol


def musicbox(f, ring=1.4, bright=1.0):
    """オルゴールの1音: ポーンと鳴ってすっと消える。倍音が少し早く消えるとそれらしくなる"""
    n = int(RATE * ring)
    out = []
    for i in range(n):
        t = i / RATE
        a = min(1.0, t / 0.004)
        v = math.sin(2 * math.pi * f * t) * math.exp(-t * 3.2)
        v += 0.35 * bright * math.sin(2 * math.pi * f * 2 * t) * math.exp(-t * 7)
        v += 0.12 * bright * math.sin(2 * math.pi * f * 3.01 * t) * math.exp(-t * 11)
        out.append(v * a)
    return out


def soft_bass(f, dur):
    """やわらかい低い音（三角波に近い形をなめらかに）"""
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        a = min(1.0, t / 0.02) * math.exp(-t * 1.6)
        v = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(2 * math.pi * f * 2 * t)
        out.append(v * a)
    return out


def tone(f0, f1, dur, kind="sine", attack=0.005, decay=None):
    n = int(RATE * dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / RATE
        if kind == "sine":
            v = math.sin(ph)
        elif kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        else:
            v = random.uniform(-1, 1)
        env = min(1.0, t / attack) if attack else 1.0
        env *= math.exp(-t * decay) if decay else max(0.0, 1 - t / dur)
        out.append(v * env)
    return out


def lowpass(s, k):
    y, out = 0.0, []
    for v in s:
        y += k * (v - y)
        out.append(y)
    return out


def song(bpm, beats_per_bar, melody, chords, bass_beats, out, bright=1.0):
    """melody: [(音 or 'R', 拍)]、chords: 小節ごとの (低音, [和音の音])。ループ用にちょうど小節の長さで作る"""
    beat = 60 / bpm
    bars = len(chords)
    total = bars * beats_per_bar * beat
    s = buf(total)
    t = 0.0
    for name, b in melody:
        if name != "R":
            for nm in name.split("+"):  # "E5+C6" で2音いっしょ
                add(s, musicbox(freq(nm), bright=bright), t, 0.55, wrap=True)
        t += b * beat
    assert abs(t - total) < 1e-6, f"メロディの長さ {t / beat} 拍 ≠ {bars * beats_per_bar} 拍"
    for i, (root, notes) in enumerate(chords):
        bar_t = i * beats_per_bar * beat
        for k in bass_beats:  # 低音
            add(s, soft_bass(freq(root), beat * 1.8), bar_t + k * beat, 0.22, wrap=True)
        for k, nm in enumerate(notes):  # 和音を小さく分散して鳴らす
            add(s, musicbox(freq(nm), ring=1.8, bright=0.4), bar_t + (k * beats_per_bar / len(notes)) * beat, 0.16, wrap=True)
    save(out, s, peak=0.55)
    print(out.name, f"{total:.1f}s")


# ---------------------------------------------------------------- 効果音
S = ROOT / "sfx"
save(S / "click.wav", tone(620, 420, 0.06, "tri", decay=40))                       # ぽこっ
save(S / "blip.wav", tone(880, 880, 0.035, "sine", attack=0.002, decay=60), 0.35)  # 文字の音（高さは話す人で変える）
save(S / "tv.wav", [a + b for a, b in zip(tone(1800, 1800, 0.25, "sine", decay=18), lowpass(tone(0, 0, 0.25, "noise", decay=25), 0.3))], 0.4)  # ぷつん
bell = buf(1.6)  # カラン（金属っぽい音は、ずれた高さの音を重ねる）
for at in (0.0, 0.16):
    for f, v in ((1568, 1.0), (2093, 0.6), (2637 * 1.007, 0.45), (3520 * 1.013, 0.25)):
        add(bell, tone(f, f, 1.4, "sine", attack=0.002, decay=4.5), at, v * (1 if at == 0 else 0.7))
save(S / "bell.wav", bell, 0.6)
save(S / "paper.wav", lowpass(tone(0, 0, 0.18, "noise", decay=20), 0.55), 0.45)    # かさっ
peri = lowpass(tone(0, 0, 0.22, "noise", attack=0.01, decay=14), 0.7)               # ぺりっ
save(S / "pack.wav", [v * (0.6 + 0.4 * math.sin(i / 90)) for i, v in enumerate(peri)], 0.5)
sp = buf(1.4)  # キラキラ（上がっていくオルゴール）
for i, nm in enumerate(["C6", "E6", "G6", "C7", "E7", "G7"]):
    add(sp, musicbox(freq(nm), ring=1.0), i * 0.07, 0.6)
save(S / "sparkle.wav", sp, 0.6)
jg = buf(3.2)  # エンディングのジングル
for at, nm in [(0, "G5"), (0.28, "E5"), (0.56, "C6"), (0.84, "B5"), (1.12, "D6"), (1.4, "C6+E6+G6")]:
    for n2 in nm.split("+"):
        add(jg, musicbox(freq(n2), ring=1.8), at, 0.5)
add(jg, soft_bass(freq("C3"), 1.6), 1.4, 0.3)
save(S / "jingle.wav", jg, 0.6)

# ---------------------------------------------------------------- 雨（4秒をくり返す）
rain = buf(4.0)
noise = lowpass([random.uniform(-1, 1) for _ in range(len(rain))], 0.25)
for i in range(len(rain)):
    rain[i] = noise[i] * 0.5
for _ in range(260):  # ぽつぽつ当たる音
    f = random.uniform(1800, 4200)
    add(rain, tone(f, f * 0.7, 0.02, "sine", attack=0.001, decay=200), random.uniform(0, 4.0), random.uniform(0.05, 0.18), wrap=True)
save(ROOT / "bgm" / "rain.wav", rain, 0.35)

# ---------------------------------------------------------------- BGM
# 昼（家・お店・喫茶店）: ハ長調・4拍子・のんびり。16小節でひとまわり
DAY_CHORDS = [
    ("C3", ["C4", "E4", "G4"]), ("A2", ["A3", "C4", "E4"]), ("F2", ["F3", "A3", "C4"]), ("G2", ["G3", "B3", "D4"]),
    ("C3", ["C4", "E4", "G4"]), ("A2", ["A3", "C4", "E4"]), ("D3", ["D4", "F4", "A4"]), ("G2", ["G3", "B3", "D4"]),
    ("F2", ["F3", "A3", "C4"]), ("G2", ["G3", "B3", "D4"]), ("E2", ["E3", "G3", "B3"]), ("A2", ["A3", "C4", "E4"]),
    ("F2", ["F3", "A3", "C4"]), ("G2", ["G3", "B3", "D4"]), ("C3", ["C4", "E4", "G4"]), ("G2", ["G3", "B3", "D4"]),
]
DAY_MELODY = [
    ("E5", 1), ("G5", 1), ("C6", 1), ("G5", 1),
    ("A5", 1.5), ("G5", 0.5), ("E5", 2),
    ("F5", 1), ("A5", 1), ("C6", 1), ("A5", 1),
    ("G5", 2), ("D5", 1), ("R", 1),
    ("E5", 1), ("G5", 1), ("C6", 1), ("E6", 1),
    ("D6", 1.5), ("C6", 0.5), ("A5", 2),
    ("F5", 1), ("A5", 1), ("D6", 1), ("C6", 1),
    ("B5", 2), ("G5", 1), ("R", 1),
    ("A5", 1), ("C6", 1), ("F6", 1.5), ("E6", 0.5),
    ("D6", 1), ("B5", 1), ("G5", 2),
    ("G5", 1), ("B5", 1), ("E6", 1.5), ("D6", 0.5),
    ("C6", 1), ("A5", 1), ("E5", 2),
    ("F5", 1), ("A5", 1), ("C6", 1), ("F6", 1),
    ("E6", 1), ("D6", 1), ("B5", 1), ("G5", 1),
    ("C6", 2), ("G5", 1), ("E5", 1),
    ("D5", 2), ("G5", 1), ("R", 1),
]
song(92, 4, DAY_MELODY, DAY_CHORDS, [0, 2], ROOT / "bgm" / "day.wav")

# 夕方（公園）: ヘ長調・3拍子のワルツ・ゆったり
EVE_CHORDS = [
    ("F2", ["F3", "A3", "C4"]), ("D2", ["D3", "F3", "A3"]), ("Bb2", ["Bb3", "D4", "F4"]), ("C3", ["C4", "E4", "G4"]),
    ("F2", ["F3", "A3", "C4"]), ("A2", ["A3", "C4", "E4"]), ("Bb2", ["Bb3", "D4", "F4"]), ("C3", ["C4", "E4", "Bb4"]),
    ("D2", ["D3", "F3", "A3"]), ("A2", ["A3", "C4", "E4"]), ("Bb2", ["Bb3", "D4", "F4"]), ("F2", ["F3", "A3", "C4"]),
    ("G2", ["G3", "Bb3", "D4"]), ("C3", ["C4", "E4", "G4"]), ("F2", ["F3", "A3", "C4"]), ("C3", ["C4", "E4", "G4"]),
]
EVE_MELODY = [
    ("C5", 1), ("F5", 1), ("A5", 1),
    ("A5", 2), ("F5", 1),
    ("D5", 1), ("F5", 1), ("Bb5", 1),
    ("G5", 3),
    ("C5", 1), ("F5", 1), ("A5", 1),
    ("C6", 2), ("A5", 1),
    ("Bb5", 1), ("A5", 1), ("F5", 1),
    ("G5", 2), ("R", 1),
    ("A5", 1), ("F5", 1), ("D5", 1),
    ("E5", 2), ("C5", 1),
    ("D5", 1), ("F5", 1), ("Bb5", 1),
    ("A5", 3),
    ("G5", 1), ("Bb5", 1), ("D6", 1),
    ("C6", 1.5), ("Bb5", 0.5), ("G5", 1),
    ("A5", 2), ("F5", 1),
    ("E5", 2), ("R", 1),
]
song(76, 3, EVE_MELODY, EVE_CHORDS, [0], ROOT / "bgm" / "evening.wav", bright=0.8)
