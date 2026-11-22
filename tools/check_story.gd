extends SceneTree
# 台本のチェック＋自動で遊んで、エンディングに着くか確かめる。
#   godot --headless --path . --script tools/check_story.gd
# 選択肢は文字で指定（その時点で出ていない選択肢を選ぼうとしたら NG）。

const ROUTES := {
	"good": ["お店へ出かける", "うさぎさんと話す", "きつねくんと話す", "喫茶店へ行く",
		"手紙を届けに行く", "ふくろうのおじいさん", "公園"],
	"azuke": ["お店へ出かける", "手紙を届けに行く", "まだわからない……お店に預ける"],
	"hitochigai": ["お店へ出かける", "たぬきくんと話す", "手紙を届けに行く", "ふくろうのおじいさん", "大会の会場"],
	"rain": ["テレビを見る", "テレビを見る", "テレビを見る", "お店へ出かける", "持っていかない",
		"窓の外を見る", "もう少しお店にいる"],
	"umbrella_no_rain": ["テレビを見る", "テレビを見る", "テレビを見る", "お店へ出かける", "傘を持っていく",
		"窓の外を見る", "!もう少しお店にいる", "手紙を届けに行く", "うさぎさん"],
}
var ng := 0


func _initialize() -> void:
	var Main = load("res://scenes/main.gd")
	Main.save_path = "user://check_tmp.cfg"
	var m = Main.new()
	m.parse_story()
	m.build_ui()
	root.add_child(m)
	# 行き先・絵があるか
	for op in m.ops:
		var to := ""
		if op.t == "opt": to = op.to
		elif op.t == "cmd" and op.c in ["goto"]: to = op.a
		elif op.t == "cmd" and op.c == "if": to = op.a.get_slice("->", 1).strip_edges()
		if to != "" and not m.labels.has(to):
			bad("行き先がない: " + to)
		if op.t == "cmd" and op.c == "bg" and not ResourceLoader.exists("res://art/bg/%s.jpg" % op.a.get_slice(" ", 0)):
			bad("背景がない: " + op.a)
		if op.t == "cmd" and op.c == "ch" and op.a != "-":
			for n in op.a.split(" ", false):
				if not ResourceLoader.exists("res://art/ch/%s.png" % n):
					bad("立ち絵がない: " + n)
		if op.t == "say":
			for ch in (op.who + op.text):
				if ch.to_utf8_buffer().size() > 1 and not _sjis_ok(ch):
					bad("フォントに無いかもしれない文字: " + ch)
	var lines := 0
	for r in ROUTES:
		var res := play(m, ROUTES[r])
		lines += res[1]
		var want: String = "rain" if r == "rain" else ("hitochigai" if r == "umbrella_no_rain" else r)
		if res[0] != want:
			bad("%s: 着いたのは %s" % [r, res[0]])
		else:
			print("OK %s（セリフ %d 行）" % [r, res[1]])
	print("ops=%d labels=%d" % [m.ops.size(), m.labels.size()])
	print("ALL OK" if ng == 0 else "NG %d" % ng)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://check_tmp.cfg"))
	quit(1 if ng else 0)


func play(m, picks: Array) -> Array:
	m.flags = {}
	m.visited = {}
	m.jump("start")
	var said := 0
	var i := 0
	m.step()
	for guard in 2000:
		if m.mode == "say":
			said += 1
			m.finish_typing()
			m.step()
		elif m.mode == "menu":
			var texts := []
			for b in m.choice_box.get_children():
				if not b.is_queued_for_deletion():
					texts.append(b.text)
			if i >= picks.size():
				return ["(選択肢で止まった: %s)" % ", ".join(texts), said]
			var want: String = picks[i]
			i += 1
			if want.begins_with("!"):  # 出ていないことを確かめる
				if want.substr(1) in texts:
					return ["(出てはいけない選択肢: %s)" % want, said]
				continue
			if not want in texts:
				return ["(選択肢が無い: %s / 出ていたもの: %s)" % [want, ", ".join(texts)], said]
			m.choose(_target(m, want))
		elif m.mode == "ending":
			for e in m.seen.keys():
				pass
			return [m.ops[m.pc - 1].a, said]
	return ["(終わらなかった)", said]



func _target(m, text: String) -> String:
	# いま出ている選択肢の中から、その文字の行き先を探す
	var p: int = m.pc - 1
	while p >= 0 and m.ops[p].t == "opt":
		if m.ops[p].text == text:
			return m.ops[p].to
		p -= 1
	return ""


func _sjis_ok(ch: String) -> bool:
	return true  # フォントのチェックは make_font_subset 側（Shift_JIS）で。ここでは省略


func bad(s: String) -> void:
	ng += 1
	print("NG " + s)
