extends SceneTree
# 後日談まわりの画面写真（全END見た後のタイトル・後日談の場面・おしまい画面）
func _initialize() -> void:
	var Main = load("res://scenes/main.gd")
	Main.save_path = "user://shot_tmp.cfg"
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	for e in m.ENDINGS:
		m.seen[e[0]] = true
	m.show_title()
	await _snap("epi_title")
	m.start_epilogue()
	for k in 3:
		m.finish_typing()
		m.step()
	await _snap("epi_scene")
	for k in 7:
		m.finish_typing()
		m.step()
	await _snap("epi_scene2")
	m.show_ending("epilogue")
	for f in 40:
		await process_frame
	await _snap("epi_end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_tmp.cfg"))
	quit()

func _snap(n: String) -> void:
	for f in 8:
		await process_frame
	root.get_texture().get_image().save_png("res://build/shots/%s.png" % n)
