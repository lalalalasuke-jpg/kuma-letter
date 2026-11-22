"""4コマ（kuma-4koma）の素材から、ゲーム用の絵を作る。
  uv run --no-project --with pillow python tools/make_art.py
背景 → art/bg/<名前>.jpg（720x540）、キャラ → art/ch/<名前>.png（切り抜き・高さ520）
まだ絵がない場所は「準備中」の仮の絵を作る（Gemini の絵ができたら差し替え）。"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
SRC = os.path.join(os.path.dirname(__file__), "..", "..", "kuma-4koma")
sys.path.insert(0, SRC)
from lib4koma import cutout  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "art")
BG = {"home": "kuma_room.jpg", "shop": "shop_playspace.png", "oripa": "shop_oripa.png",
      "register": "shop_register.jpg", "outside": "shop_outside.jpg", "showcase": "shop_showcase.jpg",
      "cafe": "cafe_inside.jpg", "park": "park_evening.jpg"}
CH = {
    "kuma": "kuma_base", "kuma_pokan": "kuma_pokan", "kuma_unazuki": "kuma_unazuki",
    "kuma_tere": "kuma_tere", "kuma_kandou": "kuma_kandou", "kuma_udegumi": "kuma_udegumi",
    "kuma_koufun": "kuma_koufun", "kuma_kami": "kuma_kami", "kuma_koucha": "kuma_koucha",
    "kuma_aseru": "kuma_aseru", "kuma_yareyare": "kuma_yareyare", "kuma_ojigi": "kuma_ojigi",
    "usagi": "usagi_base", "usagi_setsumei": "usagi_setsumei", "usagi_pokan": "usagi_pokan",
    "usagi_tefuri": "usagi_tefuri", "tanuki": "tanuki_base", "tanuki_nori": "tanuki_nori",
    "kitsune": "kitsune_base", "kitsune_megane": "kitsune_megane",
    "fukurou": "fukurou_base", "hitsuji": "hitsuji_master",
}
PLACEHOLDER = {}  # 例: {"station": ("駅", (196, 160, 120))}
FONT = "C:/Windows/Fonts/BIZ-UDGothicB.ttc"


def find(name):
    for ext in ("", ".png", ".jpg"):
        for sub in ("backgrounds", "chars"):
            p = os.path.join(SRC, sub, name + ext)
            if os.path.exists(p):
                return p
    raise FileNotFoundError(name)


def fit43(im):
    w, h = im.size
    if w / h > 4 / 3:
        nw = int(h * 4 / 3)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w * 3 / 4)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return im.resize((720, 540), Image.LANCZOS)


os.makedirs(f"{OUT}/bg", exist_ok=True)
os.makedirs(f"{OUT}/ch", exist_ok=True)
for k, f in BG.items():
    fit43(Image.open(find(f)).convert("RGB")).save(f"{OUT}/bg/{k}.jpg", quality=86)
for k, (label, col) in PLACEHOLDER.items():
    if os.path.exists(f"{OUT}/bg/{k}.jpg") and "--force" not in sys.argv:
        continue  # 本物の絵に差し替え済みなら上書きしない
    im = Image.new("RGB", (720, 540), col)
    d = ImageDraw.Draw(im)
    for y in range(540):
        t = y / 540
        d.line([(0, y), (720, y)], fill=tuple(int(c * (1.05 - 0.25 * t)) for c in col))
    f = ImageFont.truetype(FONT, 44)
    d.text((360, 250), label, font=f, fill=(255, 255, 255), anchor="mm")
    d.text((360, 310), "（絵は準備中）", font=ImageFont.truetype(FONT, 26), fill=(255, 255, 255), anchor="mm")
    im.save(f"{OUT}/bg/{k}.jpg", quality=86)
only = [a for a in sys.argv[1:] if not a.startswith("--")]  # 名前を渡すとその立ち絵だけ作る
for k, f in CH.items():
    if only and k not in only:
        continue
    c = cutout(find(f))
    c = c.resize((int(c.width * 520 / c.height), 520), Image.LANCZOS)
    c.save(f"{OUT}/ch/{k}.png")
print("ok", len(BG), len(CH))

