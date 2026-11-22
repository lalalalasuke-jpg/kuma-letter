class_name Tr

# ことばの切り替え。日本語をそのまま「見出し」にして、英語のときはこの辞書の英語を出す。
# 辞書にない文はそのまま日本語で出る。英語版は手触りを確かめたあとで足す。

static var lang := "ja"  # "ja" / "en"


static func t(s: String) -> String:
	if lang == "ja":
		return s
	return EN.get(s, s)


const EN := {}
