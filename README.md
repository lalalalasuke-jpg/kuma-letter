# くま紳士と迷子の手紙（kuma-letter）

くま紳士ららすけの、ほっこりアドベンチャー。オリパから出てきたカードに挟まっていた手紙を、持ち主に届けるお話。
1周5分くらい、エンディング4つ（図鑑つき）。Godot 4.7。

- お話: `story/story.txt`（書き方はファイルの先頭）。直したら `tools/check_story.gd` で全エンディングに着くか確かめる
  - `godot --headless --path . --script tools/check_story.gd`
- 絵: `tools/make_art.py` が `../kuma-4koma` の素材から `art/` を作る（まだ無い絵は「準備中」の仮の絵）
- 画面写真: `godot --path . --resolution 720x1280 --script tools/screenshot.gd` → `build/shots/`
- 書き出し・公開の流れは kuma-kitchen と同じ（`tools/build_web.ps1`、GitHub Pages）
