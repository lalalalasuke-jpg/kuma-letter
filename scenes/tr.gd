class_name Tr

# ことばの切り替え。日本語をそのまま「見出し」にして、英語のときは英語を出す。
#   画面の文字（ボタン・図鑑など） → 下の UI
#   お話の文（台本 story.txt）      → story/story_en.txt（ja: と en: の組）
# 辞書にない文はそのまま日本語で出る。

static var lang := "ja"  # "ja" / "en"
static var story_en := {}


static func t(s: String) -> String:
	if lang == "ja":
		return s
	if UI.has(s):
		return UI[s]
	if story_en.is_empty():
		load_story_en()
	return story_en.get(s, s)


static func has_en(s: String) -> bool:
	if story_en.is_empty():
		load_story_en()
	return UI.has(s) or story_en.has(s)


static func load_story_en() -> void:
	var f := FileAccess.open("res://story/story_en.txt", FileAccess.READ)
	if f == null:
		return
	var ja := ""
	while not f.eof_reached():
		var l := f.get_line()
		if l.begins_with("ja: "):
			ja = l.substr(4).strip_edges()
		elif l.begins_with("en: ") and ja != "":
			story_en[ja] = l.substr(4).strip_edges()
			ja = ""


const UI := {
	"くま紳士と\n迷子の手紙": "The Bear Gentleman\nand the Lost Letter",
	"はじめから": "New Game",
	"エンディング図鑑（%d/%d）": "Endings (%d/%d)",
	"おまけ：後日談": "Bonus: Epilogue",
	"タイトルへ": "Title",
	"エンディング図鑑": "Endings",
	"もどる": "Back",
	"まだ見ていないエンディング": "An ending you haven't seen yet",
	"エンディング図鑑に登録しました（%d/%d）": "Added to Endings (%d/%d)",
	"後日談がひらきました！　タイトルから見られます": "Epilogue unlocked! Play it from the title screen.",
	"あそんでくれて、ありがとうございました": "Thank you for playing!",
	"おしまい": "The End",
	# 場所
	"くまの家": "Lalasuke's Home", "カードショップ": "Card Shop", "喫茶店": "Cafe", "公園": "Park",
	# エンディング
	"届いた手紙": "The Letter Delivered",
	"手がかりを集めて、ふくろうのおじいさんに手紙を届けた": "You gathered clues and delivered the letter to old Mr. Owl.",
	"お店に預けた手紙": "The Letter Left at the Shop",
	"手紙はお店から、持ち主のもとへ": "The letter found its way home from the shop.",
	"人ちがい": "Wrong Person",
	"思いきって声をかけたけれど……": "You worked up the courage to ask, but...",
	"紳士、沼にはまる": "A Gentleman Gets Hooked",
	"占いの1位を信じて、オリパを引きつづけた": "Trusting the horoscope, you kept buying mystery packs.",
	"雨宿りの約束": "A Promise in the Rain",
	"雨の日のお店で、あの日の続きが始まった": "On a rainy day at the shop, the unfinished match began again.",
	"後日談": "Epilogue",
	"いつものお店に、新しい「いつもの」が増えた": "The usual shop gained a new \"usual.\"",
}
