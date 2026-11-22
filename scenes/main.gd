extends Control
# くま紳士と迷子の手紙 — 台本（story/story.txt）を読んで進める、小さなアドベンチャーの本体。
# 画面: 上に場所の帯 → 背景＋立ち絵（4:3）→ セリフの枠 → 選択肢。
# お話を直すときは story.txt だけを直せばよい（書き方は story.txt の先頭）。

const STORY := "res://story/story.txt"
const SAVE := "user://kuma_letter.cfg"
const W := 720
const BG_Y := 80
const BG_H := 540

# エンディング: [名前, タイトル, ひとこと]
const ENDINGS := [
	["good", "届いた手紙", "手がかりを集めて、ふくろうのおじいさんに手紙を届けた"],
	["azuke", "お店に預けた手紙", "手紙はお店から、持ち主のもとへ"],
	["hitochigai", "人ちがい", "思いきって声をかけたけれど……"],
	["rain", "雨宿りの約束", "雨の日のお店で、あの日の続きが始まった"],
]
const PLACE := {"home": "くまの家", "outside": "カードショップ", "oripa": "カードショップ",
	"shop": "カードショップ", "register": "カードショップ", "showcase": "カードショップ",
	"cafe": "喫茶店", "park": "公園", "park_rain": "公園"}

const NO_FLIP := []  # 左に置いても反転しない立ち絵の名前（正面向きの絵など）
static var save_path := SAVE  # テスト用に差し替えられるように

var ops: Array = []          # 台本を1行ずつにしたもの
var labels := {}             # *名前 → 行番号
var pc := 0
var flags := {}
var visited := {}
var seen := {}               # 見たエンディング
var mode := "title"          # title / say / menu / ending / gallery
var typing := false
var tw: Tween

var bg_rect: TextureRect
var rain: Rain
var char_layer: Control
var place_label: Label
var text_panel: Panel
var name_label: Label
var text_label: Label
var next_mark: Label
var choice_box: GridContainer
var overlay: Control


func _ready() -> void:
	load_save()
	parse_story()
	build_ui()
	show_title()


# ---------------------------------------------------------------- 台本の読み込み
func parse_story() -> void:
	var f := FileAccess.open(STORY, FileAccess.READ)
	var re := RegEx.new()
	re.compile("^(.+?)「(.*)」$")
	while not f.eof_reached():
		var s := f.get_line().strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		if s.begins_with("*"):
			labels[s.substr(1)] = ops.size()
		elif s.begins_with("@"):
			var parts := s.substr(1).split(" ", false, 1)
			ops.append({"t": "cmd", "c": parts[0], "a": parts[1] if parts.size() > 1 else ""})
		elif s.begins_with("- "):
			var body := s.substr(2)
			var cond := ""
			if body.contains(" ? "):
				cond = body.get_slice(" ? ", 1).strip_edges()
				body = body.get_slice(" ? ", 0)
			ops.append({"t": "opt", "text": body.get_slice(" -> ", 0).strip_edges(),
				"to": body.get_slice(" -> ", 1).strip_edges(), "cond": cond})
		else:
			var m := re.search(s)
			if m:
				ops.append({"t": "say", "who": m.get_string(1), "text": m.get_string(2)})
			else:
				ops.append({"t": "say", "who": "", "text": s})


func check(cond: String) -> bool:
	if cond == "":
		return true
	for any in cond.split("|"):
		var ok := true
		for a in any.split("&"):
			a = a.strip_edges()
			if a.begins_with("!"):
				ok = ok and int(flags.get(a.substr(1), 0)) == 0
			elif a.contains(">="):
				ok = ok and int(flags.get(a.get_slice(">=", 0), 0)) >= int(a.get_slice(">=", 1))
			else:
				ok = ok and int(flags.get(a, 0)) != 0
		if ok:
			return true
	return false


func jump(label: String) -> void:
	if not labels.has(label):
		push_error("台本に *%s がない" % label)
		return
	visited[label] = true
	pc = labels[label]


# ---------------------------------------------------------------- 進める
func start_game() -> void:
	flags = {}
	visited = {}
	clear_overlay()
	text_panel.show()
	jump("start")
	step()


func step() -> void:
	clear_choices()
	while pc < ops.size():
		var op: Dictionary = ops[pc]
		match op.t:
			"say":
				pc += 1
				show_line(op.who, op.text)
				return
			"opt":
				var opts := []
				while pc < ops.size() and ops[pc].t == "opt":
					if check(ops[pc].cond):
						opts.append(ops[pc])
					pc += 1
				show_choices(opts)
				return
			"cmd":
				pc += 1
				var a: String = op.a
				match op.c:
					"bg": set_bg(a)
					"ch": set_chars(a)
					"set": flags[a] = 1
					"add": flags[a] = int(flags.get(a, 0)) + 1
					"goto":
						jump(a)
					"if":
						if check(a.get_slice("->", 0).strip_edges()):
							jump(a.get_slice("->", 1).strip_edges())
					"end":
						show_ending(a)
						return
					_:
						push_error("知らない命令 @%s" % op.c)


func tap() -> void:
	if mode != "say":
		return
	if typing:
		finish_typing()
	else:
		step()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tap()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_accept"):
		tap()


# ---------------------------------------------------------------- 画面
func build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color("f6efe4")
	base.size = Vector2(W, 1280)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	var bar := ColorRect.new()
	bar.color = Color("5a4636")
	bar.size = Vector2(W, BG_Y)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	place_label = label("", 30, Color.WHITE)
	place_label.position = Vector2(24, 18)
	add_child(place_label)
	var menu_btn := button("タイトルへ", 22)
	menu_btn.position = Vector2(W - 170, 14)
	menu_btn.size = Vector2(150, 52)
	menu_btn.pressed.connect(show_title)
	add_child(menu_btn)

	var stage := Control.new()
	stage.position = Vector2(0, BG_Y)
	stage.size = Vector2(W, BG_H)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	bg_rect = TextureRect.new()
	bg_rect.size = Vector2(W, BG_H)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg_rect)
	char_layer = Control.new()
	char_layer.size = Vector2(W, BG_H)
	char_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(char_layer)
	rain = Rain.new()
	rain.size = Vector2(W, BG_H)
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain.hide()
	stage.add_child(rain)

	text_panel = Panel.new()
	text_panel.position = Vector2(16, BG_Y + BG_H + 16)
	text_panel.size = Vector2(W - 32, 280)
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_theme_stylebox_override("panel", box(Color("fffaf2"), Color("5a4636")))
	add_child(text_panel)
	name_label = label("", 26, Color("a0522d"))
	name_label.position = Vector2(24, 14)
	text_panel.add_child(name_label)
	text_label = label("", 31, Color("3a2a20"))
	text_label.position = Vector2(24, 56)
	text_label.size = Vector2(W - 32 - 48, 210)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_panel.add_child(text_label)
	next_mark = label("▼", 22, Color("a0522d"))
	next_mark.position = Vector2(W - 32 - 44, 244)
	text_panel.add_child(next_mark)

	choice_box = GridContainer.new()
	choice_box.position = Vector2(16, BG_Y + BG_H + 312)
	choice_box.size = Vector2(W - 32, 0)
	choice_box.add_theme_constant_override("h_separation", 10)
	choice_box.add_theme_constant_override("v_separation", 8)
	add_child(choice_box)

	overlay = Control.new()
	overlay.size = Vector2(W, 1280)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


func set_bg(a: String) -> void:
	var name := a.get_slice(" ", 0)
	bg_rect.texture = load("res://art/bg/%s.jpg" % name)
	place_label.text = Tr.t(PLACE.get(name, ""))
	var wet := a.contains("rain")
	rain.visible = wet
	bg_rect.modulate = Color(0.62, 0.66, 0.78) if wet else Color.WHITE


func set_chars(a: String) -> void:
	for c in char_layer.get_children():
		c.queue_free()
	if a.strip_edges() == "-":
		return
	var names := a.split(" ", false)
	# 2人のときは、くまをいつも右に（モノクルがあるので反転しない）。左の人は反転して右向き＝くまと向かい合う
	if names.size() == 2 and names[0].begins_with("kuma"):
		names = PackedStringArray([names[1], names[0]])
	var xs := [W / 2.0] if names.size() == 1 else [W * 0.28, W * 0.72]
	for i in names.size():
		var tex: Texture2D = load("res://art/ch/%s.png" % names[i])
		var h := 420.0
		var sc := h / tex.get_height()
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.size = Vector2(tex.get_width() * sc, h)
		t.position = Vector2(xs[i] - t.size.x / 2, BG_H - h - 6)
		t.flip_h = names.size() == 2 and i == 0 and not names[i] in NO_FLIP
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		char_layer.add_child(t)


func show_line(who: String, text: String) -> void:
	mode = "say"
	name_label.text = Tr.t(who)
	text_label.text = Tr.t(text).replace("\\n", "\n")  # 台本の \n で改行
	text_label.visible_characters = 0
	next_mark.hide()
	typing = true
	if tw:
		tw.kill()
	tw = create_tween()
	var n := text_label.get_total_character_count()
	tw.tween_property(text_label, "visible_characters", n, n * 0.035)
	tw.tween_callback(finish_typing)


func finish_typing() -> void:
	if tw:
		tw.kill()
	typing = false
	text_label.visible_characters = -1
	next_mark.visible = mode == "say"


func show_choices(opts: Array) -> void:
	mode = "menu"
	finish_typing()
	next_mark.hide()
	choice_box.columns = 2 if opts.size() > 5 else 1
	var bw := (W - 32 - 10) / 2.0 if choice_box.columns == 2 else W - 32.0
	for o in opts:
		var b := button(o.text, 25)
		b.custom_minimum_size = Vector2(bw, 64 if opts.size() <= 5 else 70)
		if visited.has(o.to):  # もう見た選択肢は少しうすく
			b.add_theme_color_override("font_color", Color("9a8a7c"))
		b.pressed.connect(func(): choose(o.to))
		choice_box.add_child(b)


func choose(to: String) -> void:
	jump(to)
	step()


func clear_choices() -> void:
	for c in choice_box.get_children():
		c.queue_free()


# ---------------------------------------------------------------- タイトル・エンディング・図鑑
func clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func cover(col: Color) -> Control:
	clear_overlay()
	clear_choices()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(W, 1280)
	overlay.add_child(r)
	return r


func show_title() -> void:
	mode = "title"
	text_panel.hide()
	if tw:
		tw.kill()
	cover(Color("f6efe4"))
	var pic := TextureRect.new()
	pic.texture = load("res://art/bg/showcase.jpg")
	pic.position = Vector2(0, 0)
	pic.size = Vector2(W, BG_H)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.add_child(pic)
	var kuma := TextureRect.new()
	kuma.texture = load("res://art/ch/kuma_kami.png")
	kuma.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kuma.size = Vector2(300, 360)
	kuma.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	kuma.position = Vector2(W / 2.0 - 150, BG_H - 340)
	overlay.add_child(kuma)
	var t := label("くま紳士と\n迷子の手紙", 64, Color("5a4636"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, BG_H + 40)
	t.size = Vector2(W, 180)
	overlay.add_child(t)
	var y := BG_H + 280
	for item in [["はじめから", start_game], ["エンディング図鑑（%d/%d）" % [seen.size(), ENDINGS.size()], show_gallery]]:
		var b := button(item[0], 30)
		b.position = Vector2(120, y)
		b.size = Vector2(W - 240, 90)
		b.pressed.connect(item[1])
		overlay.add_child(b)
		y += 120


func show_ending(id: String) -> void:
	mode = "ending"
	var first := not seen.has(id)
	seen[id] = true
	write_save()
	text_panel.hide()
	var e: Array = ENDINGS.filter(func(x): return x[0] == id)[0]
	if is_inside_tree():
		await get_tree().create_timer(0.4).timeout
	cover(Color(0.2, 0.15, 0.1, 0.94))
	var t := label("END\n「%s」" % Tr.t(e[1]), 52, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 360)
	t.size = Vector2(W, 200)
	overlay.add_child(t)
	var s := label(Tr.t(e[2]), 26, Color("f0e0c8"))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.position = Vector2(60, 580)
	s.size = Vector2(W - 120, 120)
	overlay.add_child(s)
	if first:
		var n := label("エンディング図鑑に登録しました（%d/%d）" % [seen.size(), ENDINGS.size()], 24, Color("ffd27a"))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.position = Vector2(0, 720)
		n.size = Vector2(W, 40)
		overlay.add_child(n)
	var b := button("タイトルへ", 30)
	b.position = Vector2(160, 860)
	b.size = Vector2(W - 320, 90)
	b.pressed.connect(show_title)
	overlay.add_child(b)


func show_gallery() -> void:
	mode = "gallery"
	cover(Color("f6efe4"))
	var t := label("エンディング図鑑", 44, Color("5a4636"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 60)
	t.size = Vector2(W, 60)
	overlay.add_child(t)
	var y := 170
	for i in ENDINGS.size():
		var e: Array = ENDINGS[i]
		var got := seen.has(e[0])
		var p := Panel.new()
		p.position = Vector2(40, y)
		p.size = Vector2(W - 80, 190)
		p.add_theme_stylebox_override("panel", box(Color("fffaf2") if got else Color("e6ddd0"), Color("5a4636")))
		overlay.add_child(p)
		var head := label("%d. %s" % [i + 1, Tr.t(e[1]) if got else "？？？"], 32, Color("5a4636"))
		head.position = Vector2(24, 20)
		p.add_child(head)
		var body := label(Tr.t(e[2]) if got else "まだ見ていないエンディング", 24, Color("6a5a4c"))
		body.position = Vector2(24, 80)
		body.size = Vector2(W - 128, 100)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(body)
		y += 210
	var b := button("もどる", 30)
	b.position = Vector2(160, 1040)
	b.size = Vector2(W - 320, 90)
	b.pressed.connect(show_title)
	overlay.add_child(b)


# ---------------------------------------------------------------- 保存
func load_save() -> void:
	var c := ConfigFile.new()
	if c.load(save_path) == OK:
		for k in c.get_value("endings", "seen", []):
			seen[k] = true


func write_save() -> void:
	var c := ConfigFile.new()
	c.set_value("endings", "seen", seen.keys())
	c.save(save_path)


# ---------------------------------------------------------------- 部品
func label(s: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = Tr.t(s)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func button(s: String, size: int) -> Button:
	var b := Button.new()
	b.text = Tr.t(s)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color("3a2a20"))
	b.add_theme_color_override("font_hover_color", Color("3a2a20"))
	b.add_theme_color_override("font_pressed_color", Color("3a2a20"))
	b.add_theme_stylebox_override("normal", box(Color("fff3dc"), Color("a0522d")))
	b.add_theme_stylebox_override("hover", box(Color("ffe9c2"), Color("a0522d")))
	b.add_theme_stylebox_override("pressed", box(Color("f5d9a8"), Color("a0522d")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(16)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


# 雨（線をななめに降らせる）
class Rain extends Control:
	var drops := []

	func _ready() -> void:
		for i in 90:
			drops.append(Vector2(randf() * 760, randf() * 540))

	func _process(delta: float) -> void:
		if not visible:
			return
		for i in drops.size():
			drops[i] += Vector2(-120, 900) * delta
			if drops[i].y > 560:
				drops[i] = Vector2(randf() * 800, -20)
		queue_redraw()

	func _draw() -> void:
		for d in drops:
			draw_line(d, d + Vector2(-6, 34), Color(0.85, 0.9, 1.0, 0.55), 2.0)
