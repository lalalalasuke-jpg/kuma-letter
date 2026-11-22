extends SceneTree
# いくつかの場面の画面写真を build/shots/ に撮る（ウィンドウありで実行）
#   godot --path . --resolution 720x1280 --script tools/screenshot.gd
const SHOTS := [
	["title", []],
	["home_menu", ["start"]],
	["oripa", ["go_shop", 9]],
	["shop_menu", ["shop"]],
	["tanuki", ["talk_tanuki", 3]],
	["rain", ["stay", 9]],
	["good", ["good", 4]],
	["cafe", ["cafe", 2]],
	["park", ["good", 0]],
]


func _initialize() -> void:
	var Main = load("res://scenes/main.gd")
	Main.save_path = "user://shot_tmp.cfg"
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	DirAccess.make_dir_recursive_absolute("res://build/shots")
	for s in SHOTS:
		if s[1].size() > 0:
			m.clear_overlay()
			m.text_panel.show()
			m.jump(s[1][0])
			m.step()
			for k in (s[1][1] if s[1].size() > 1 else 0):
				m.finish_typing()
				m.step()
			m.finish_typing()
		for f in 8:
			await process_frame
		root.get_texture().get_image().save_png("res://build/shots/%s.png" % s[0])
	if s_has_ending(m):
		pass
	m.show_ending("rain")
	for f in 40:
		await process_frame
	root.get_texture().get_image().save_png("res://build/shots/ending.png")
	m.show_gallery()
	for f in 8:
		await process_frame
	root.get_texture().get_image().save_png("res://build/shots/gallery.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_tmp.cfg"))
	quit()


func s_has_ending(_m) -> bool:
	return false
