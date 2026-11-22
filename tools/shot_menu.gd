extends SceneTree
# 選択肢がいちばん多い画面（推理の5択・お店の8択）の写真を撮って、はみ出しを確かめる
func _initialize() -> void:
	var Main = load("res://scenes/main.gd")
	Main.save_path = "user://shot_tmp.cfg"
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.clear_overlay()
	m.text_panel.show()
	for f in [["c_tanuki", 1], ["cloud", 1]]:
		m.flags[f[0]] = f[1]
	for s in ["deduce", "shop"]:
		m.jump(s)
		m.step()
		while m.mode == "say":
			m.finish_typing()
			m.step()
		for i in 8:
			await process_frame
		var bottom := 0.0
		for b in m.choice_box.get_children():
			bottom = max(bottom, b.get_global_rect().end.y)
		print("%s: 選択肢 %d 個、いちばん下 %d（画面は1280）" % [s, m.choice_box.get_child_count(), bottom])
		root.get_texture().get_image().save_png("res://build/shots/menu_%s.png" % s)
	quit()
