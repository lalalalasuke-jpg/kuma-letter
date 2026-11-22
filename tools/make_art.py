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
      "register": "shop_register.jpg", "outside": "shop_outside.jpg", "showcase": "shop_showcase.jpg"}
CH = {
    "kuma": "kuma_base", "kuma_pokan": "kuma_pokan", "kuma_unazuki": "kuma_unazuki",
    "kuma_tere": "kuma_tere", "kuma_kandou": "kuma_kandou", "kuma_udegumi": "kuma_udegumi",
    "kuma_koufun": "kuma_koufun", "kuma_kami": "kuma_kami", "kuma_koucha": "kuma_koucha",
    "kuma_aseru": "kuma_aseru", "kuma_yareyare": "kuma_yareyare", "kuma_ojigi": "kuma_ojigi",
    "usagi": "usagi_base", "usagi_setsumei": "usagi_setsumei", "usagi_pokan": "usagi_pokan",
    "usagi_tefuri": "usagi_tefuri", "tanuki": "tanuki_base", "tanuki_nori": "tanuki_nori",
    "kitsune": "kitsune_base", "kitsune_megane": "kitsune_megane",
}
PLACEHOLDER = {"cafe": ("喫茶店", (196, 160, 120)), "park": ("夕方の公園", (240, 180, 130)),
               "park_rain": ("雨あがりの公園", (170, 190, 210))}
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
for k, f in CH.items():
    c = cutout(find(f))
    c = c.resize((int(c.width * 520 / c.height), 520), Image.LANCZOS)
    c.save(f"{OUT}/ch/{k}.png")
print("ok", len(BG), len(CH))

# ふくろうの仮の立ち絵（Gemini の絵ができたら art/ch/fukurou.png を差し替え）
if not os.path.exists(f"{OUT}/ch/fukurou.png") or "--force" in sys.argv:
    im = Image.new("RGBA", (360, 520), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    brown, belly, ink = (150, 110, 80, 255), (230, 210, 180, 255), (60, 40, 30, 255)
    d.ellipse((40, 120, 320, 500), fill=brown, outline=ink, width=5)
    d.polygon([(70, 160), (100, 70), (140, 140)], fill=brown, outline=ink)
    d.polygon([(290, 160), (260, 70), (220, 140)], fill=brown, outline=ink)
    d.ellipse((100, 260, 260, 480), fill=belly)
    for cx in (130, 230):
        d.ellipse((cx - 48, 150, cx + 48, 246), fill=(255, 255, 255, 255), outline=ink, width=4)
        d.arc((cx - 26, 180, cx + 26, 220), 200, 340, fill=ink, width=6)  # にこにこの目
    d.polygon([(165, 230), (195, 230), (180, 262)], fill=(240, 170, 60, 255), outline=ink)
    d.text((180, 420), "（仮）", font=ImageFont.truetype(FONT, 30), fill=ink, anchor="mm")
    im.save(f"{OUT}/ch/fukurou.png")
