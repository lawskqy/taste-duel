extends SceneTree

var failures: Array[String] = []
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func settled() -> void:
	for frame in range(8):
		await process_frame

func check_bounds(node: Node, screen: String) -> void:
	if node is CanvasLayer and not node.visible:
		return
	if node is Control:
		if not node.is_visible_in_tree():
			return
		var rect = node.get_global_rect()
		var viewport = root.get_visible_rect().grow(1)
		check(viewport.encloses(rect), "%s: %s escapes viewport: %s" % [screen, node.get_path(), rect])
		# Scrolled content is allowed outside the viewport; its clipping parent is not.
		if node is ScrollContainer:
			return
	for child in node.get_children():
		check_bounds(child, screen)

func run() -> void:
	var manager = root.get_node("GameManager")
	manager.sound_enabled = false
	manager.reduce_motion = true
	manager.set_profile(0, "WWWWWWWWWWWWWWWW", 0, 0)
	manager.set_profile(1, "WWWWWWWWWWWWWWWW", 3, 3)
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		root.size = dimensions
		change_scene_to_file("res://scenes/Main.tscn")
		await settled()
		var main = current_scene
		check_bounds(main, "menu %s" % dimensions)
		main._show_settings()
		await settled()
		check_bounds(main, "settings")
		main._show_customization()
		await settled()
		check_bounds(main, "customization")
		main._start_match()
		await settled()
		check_bounds(main, "unsorted rankings")
		main.current_form._on_randomize()
		await settled()
		check_bounds(main, "sorted rankings")
		for list in [main.current_form.dislike_list, main.current_form.neutral_list, main.current_form.like_list]:
			for card in list.get_children():
				check(not card.dish_name.get_global_rect().intersects(card.power.get_global_rect()), "name and power have separate lines")
		main._show_pass_device_prompt()
		await settled()
		check_bounds(main, "handoff")
		main._show_leave_round_dialog()
		await settled()
		check_bounds(main, "leave rankings")
		change_scene_to_file("res://scenes/battle.tscn")
		await settled()
		var battle = current_scene
		battle.animation_duration = 0
		battle.select_item(battle.player1.pool[0].id)
		battle._turn_notice.text = "WWWWWWWWWWWWWWWW plays again.\n" + "WWWWWWWWWWWWWWWW uses a bonus turn from an earlier card with a long name.\n".repeat(4)
		battle.effect_popup.text = "A long resolution message.\n".repeat(24)
		battle._buff_labels[0].text = "A lasting effect with a long description.\n".repeat(18)
		await settled()
		check_bounds(battle, "battle")
		var card = battle.played_cards.get_child(0)
		check(not card.get_global_rect().intersects(battle.effect_popup.get_parent().get_global_rect()), "played card and message viewport stay apart")
		check(not battle._play_button.get_global_rect().intersects(battle.effect_popup.get_parent().get_global_rect()), "messages cannot cover play button")
		battle._open_pool(battle.player1)
		await settled()
		check_bounds(battle, "card pool")
		battle._pool_layer.hide()
		for panel in [battle._settings_panel, battle._history_panel, battle._leave_panel, battle.reclaim_panel]:
			panel.show()
			await settled()
			check_bounds(battle, "battle dialog")
			panel.hide()
		battle._end_battle("Player 1", "Both menus are empty. Highest HP takes the table.")
		await settled()
		check_bounds(battle, "result")
	current_scene.queue_free()
	await settled()
	print("UI LAYOUT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
