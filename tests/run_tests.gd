extends SceneTree

var checks: int = 0
var failures: Array[String] = []
var manager: Node
const CARD = "margherita_pizza"
const SECOND = "cheeseburger"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func fresh_battle():
	manager.reset()
	# Keep combat fixtures stable while production samples randomly from each 50-item theme.
	manager.items = manager.theme_items("food").slice(0, GameManager.ITEM_COUNT_PER_MATCH)
	var battle = load("res://scenes/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	battle.animation_duration = 0
	for player in [battle.player1, battle.player2]:
		player.preferences.clear()
	battle.available_effects.clear()
	return battle

func dispose(node: Node) -> void:
	node.queue_free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	manager = root.get_node("GameManager")
	manager.reset_profiles()
	await test_combat()
	await test_balance_limits()
	await test_effects()
	await test_return_card_turns()
	await test_effect_ownership()
	await test_shared_effect_pool()
	await test_customization()
	await test_forms()
	await test_matches()
	await test_scene_flow()
	print("MVP TESTS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_combat() -> void:
	var b = await fresh_battle()
	b.player2.preferences[CARD] = {"category": "disliked", "rank": 4}
	await b.play_item(CARD)
	check(b.player1.hp == 100 and b.player2.hp == 76, "rank damage")
	check(b.hp_bar_p1.value == 100 and b.hp_bar_p2.value == 76, "correct HP bars")
	check(b.current_turn == 1 and b.player1.pool.size() == 20, "card spent and turn changes")
	await process_frame
	await process_frame
	check(b.played_cards.get_child(0).size.y <= 180, "played card visual stays within table")
	for list in [b.card_list_p1, b.card_list_p2]:
		check(list.get_parent().get_global_rect().end.y <= 720, "battle pool scroll fits viewport")
	var count = b.played_cards_list.size()
	await b.play_item("missing")
	check(b.played_cards_list.size() == count and b.current_turn == 1, "invalid card rejected")
	await dispose(b)

	b = await fresh_battle()
	b.player1.hp = 5
	b.player2.hp = 50
	b.player2.preferences[CARD] = {"category": "liked", "rank": 1}
	b.available_effects = {19: b.effects_pool[19]}
	await b.play_item(CARD)
	check(b.player1.hp == 0 and b.state == b.BattleState.BATTLE_OVER, "self damage knockout")
	check(b.win_screen.title_label.text == "Player 2 wins!", "self damage winner")
	await dispose(b)

	b = await fresh_battle()
	b.player2.hp = 10
	b.player2.preferences[CARD] = {"category": "disliked", "rank": 1}
	b.available_effects = {7: b.effects_pool[7]}
	await b.play_item(CARD)
	check(b.state == b.BattleState.BATTLE_OVER and b.player2.hp == 0, "base damage knockout")
	check(b.available_effects.size() == 1, "no effects after knockout")
	b.player1.hp = 0
	b._check_knockout()
	check(b.win_screen.title_label.text == "It's a draw!", "simultaneous knockout draw")
	await dispose(b)

	b = await fresh_battle()
	b.player1.pool = [manager.get_item(CARD)]
	b.player2.pool = [manager.get_item(CARD), manager.get_item(SECOND)]
	await b.play_item(CARD)
	await b.play_item(CARD)
	check(b.current_turn == 1 and b.state == b.BattleState.WAITING_FOR_CARD, "empty player skipped")
	await b.play_item(SECOND)
	check(b.state == b.BattleState.BATTLE_OVER and b.win_screen.title_label.text == "It's a draw!", "exhausted pools end")
	await dispose(b)

	b = await fresh_battle()
	b._apply_effect(b.effects_pool[1], b.player1, b.player2)
	await b.play_item(CARD)
	check("dmg_mult" in b.player1.active_buffs, "neutral preserves damage buff")
	await b.play_item(CARD)
	b.player2.preferences[SECOND] = {"category": "liked", "rank": 4}
	b.player2.hp = 50
	await b.play_item(SECOND)
	check(b.player2.hp == 60 and "dmg_mult" in b.player1.active_buffs, "damage buff does not modify healing")
	await b.play_item(SECOND)
	b.player2.preferences["ramen"] = {"category": "disliked", "rank": 7}
	await b.play_item("ramen")
	check(b.player2.hp == 24 and "dmg_mult" not in b.player1.active_buffs, "buff applied once on damage")
	await dispose(b)

	b = await fresh_battle()
	b.player1.pool = [manager.get_item(CARD)]
	b.player2.pool = [manager.get_item(SECOND)]
	b.player2.preferences[CARD] = {"category": "disliked", "rank": 3}
	b.available_effects = {15: b.effects_pool[15]}
	await b.play_item(CARD)
	check(b.player1.has_item(SECOND) and not b.player2.has_item(CARD), "swap uses pools after card consumption")
	check(b.current_turn == 0, "swap to empty pool does not stall")
	await dispose(b)

	b = await fresh_battle()
	b.player1.pool = [manager.get_item(CARD)]
	b.player2.pool.clear()
	b.player1.active_buffs.append("skip_turn")
	b.player2.active_buffs.append("skip_turn")
	b._finish_turn()
	check(b.current_turn == 0 and b.state == b.BattleState.WAITING_FOR_CARD, "both skips and empty pool terminate")
	await dispose(b)

	b = await fresh_battle()
	b.animation_duration = 0.05
	b.play_item(CARD)
	check(b.state == b.BattleState.RESOLVING, "input locked during animation")
	b.play_item(SECOND)
	check(b.played_cards_list.size() == 1, "rapid second click rejected")
	await create_timer(0.1).timeout
	check(b.state == b.BattleState.WAITING_FOR_CARD, "animation unlocks turn")
	await dispose(b)

func test_return_card_turns() -> void:
	# The reported two-effect draw, with and without earlier turn-changing effects.
	for turn in [0, 1]:
		for scenario in ["normal", "bonus", "skip", "empty", "last_card"]:
			var b = await fresh_battle()
			b.current_turn = turn
			var attacker = b.get_current_player()
			var opponent = b.get_opponent()
			b._last_played_name = "Earlier card"
			if scenario == "bonus":
				b._apply_effect(b.effects_pool[13], attacker, opponent)
			elif scenario == "skip":
				b._apply_effect(b.effects_pool[14], attacker, opponent)
			elif scenario == "empty":
				opponent.pool = [manager.get_item(SECOND)]
			elif scenario == "last_card":
				attacker.pool = [manager.get_item(CARD)]
			var attacker_count: int = attacker.pool.size()
			var opponent_count: int = opponent.pool.size()
			opponent.preferences[CARD] = {"category": "disliked", "rank": 1}
			b.available_effects = {12: b.effects_pool[12], 26: b.effects_pool[26]}
			await b.play_item(CARD)
			var context = "P%d return + destroy (%s)" % [turn + 1, scenario]
			check(opponent.hp == 70 and attacker.hp == 100, context + " deals 30 damage")
			check(attacker.pool.size() == attacker_count and attacker.has_item(CARD), context + " restores played card")
			check(opponent.pool.size() == opponent_count - 1, context + " destroys opponent card")
			check(b.effect_history.size() == 2 and b.used_effect_ids.has(12) and b.used_effect_ids.has(26), context + " draws exactly the reported effects")
			var repeat_turn = scenario in ["bonus", "skip", "empty"]
			check(b.current_turn == (turn if repeat_turn else 1 - turn), context + " selects correct next player")
			check(attacker.bonus_turns == 0 and opponent.bonus_turns == 0, context + " return grants no bonus")
			var notice: String = b._turn_notice.text
			if scenario == "bonus":
				check("bonus turn" in notice and "Play 1 more card from Earlier card" in notice, context + " explains earlier bonus source")
			elif scenario == "skip":
				check("skips a turn" in notice and "Enemy skips next turn from Earlier card" in notice, context + " explains earlier skip source")
			elif scenario == "empty":
				check("has no cards" in notice, context + " explains exhausted opponent")
			else:
				check("plays next" in notice and b._turn_reasons.is_empty(), context + " normal handoff")
			b.select_item(b.get_current_player().pool[0].id)
			check(b._turn_notice.visible and b._turn_notice.text == notice, context + " explanation survives card selection")
			b._show_history()
			check(notice in b._history_text.text, context + " journal preserves handoff")
			b._history_panel.hide()
			if scenario == "bonus" or scenario == "skip":
				await b.play_item(SECOND)
				check(b.current_turn == 1 - turn and b._turn_reasons.is_empty(), context + " extra play ends normally and clears explanation")
			await dispose(b)

func test_effects() -> void:
	# Every effect receives its own clean fixture and a concrete expected result.
	for id in range(1, 31):
		var b = await fresh_battle()
		var p = b.player1
		var other = b.player2
		p.hp = 50
		p.pool = [manager.get_item(SECOND)]
		other.pool = [manager.get_item("ramen")]
		other.last_effect = b.effects_pool[6].duplicate(true)
		b.played_cards_list = [CARD]
		b._played_discard_index = 0
		b._apply_effect(b.effects_pool[id], p, other)
		match id:
			1: check(b._apply_damage_modifiers(p, 20) == 40, "effect 1")
			2: check(b._apply_damage_modifiers(p, 20) == 25, "effect 2")
			3: check(b._apply_damage_modifiers(p, 20) == 26, "effect 3")
			4: check(b._apply_damage_modifiers(p, 20) == 30, "effect 4")
			5: check(b._apply_damage_modifiers(p, 20) == 30, "effect 5")
			6: check(p.hp == 58, "effect 6")
			7: check(p.hp == 66, "effect 7")
			8: check(p.hp == 56 and p.max_hp == 106, "effect 8")
			9: check(p.hp == 57, "effect 9")
			10: check(b._reclaim_targets == [p], "effect 10")
			11: check(p.pool.size() == 2 and p.pool[1].id == SECOND, "effect 11")
			12: check(p.has_item(CARD) and b.played_cards_list.is_empty(), "effect 12")
			13: check(p.bonus_turns == 1 and other.bonus_turns == 0, "effect 13")
			14: check("skip_turn" in other.active_buffs and "skip_turn" not in p.active_buffs, "effect 14")
			15: check(p.has_item("ramen") and other.has_item(SECOND), "effect 15")
			16: check(b._apply_damage_modifiers(p, 20) == 10, "effect 16")
			17: check(b._apply_damage_modifiers(p, 20) == 15, "effect 17")
			18: check(b._apply_damage_modifiers(p, 20) == 0, "effect 18")
			19: check(p.hp == 40, "effect 19")
			20: check(p.hp == 40, "effect 20")
			21:
				p.heal(10)
				check(p.hp == 50, "effect 21")
			22: check(p.hp == 40, "effect 22")
			23, 24: check(p.pool.is_empty() and SECOND in b.played_cards_list, "effect %d" % id)
			25: check(b._apply_damage_modifiers(p, 20) == 16, "effect 25")
			26: check(p.pool.is_empty() and SECOND not in b.played_cards_list, "effect 26")
			27: check("skip_turn" in p.active_buffs, "effect 27")
			28: check(other.bonus_turns == 1 and p.bonus_turns == 0, "effect 28")
			29:
				b._apply_effect(b.effects_pool[19], p, other)
				check(p.hp == 50 and other.hp == 90 and not p.reverse_next_effect, "effect 29")
			30: check(p.hp == 50 and p.max_hp == 94, "effect 30")
		await dispose(b)

	var b = await fresh_battle()
	b.played_cards_list = [CARD, CARD]
	b._played_discard_index = 1
	var before_return = b.player1.pool.size()
	b._apply_effect(b.effects_pool[12], b.player1, b.player2)
	b._apply_effect(b.effects_pool[12], b.player1, b.player2)
	check(b.player1.pool.size() == before_return + 1 and b.played_cards_list.size() == 1, "return cannot retrieve older identical card twice")
	await dispose(b)

	b = await fresh_battle()
	b.player2.preferences[CARD] = {"category": "liked", "rank": 3}
	b.available_effects = {13: b.effects_pool[13]}
	await b.play_item(CARD)
	check(b.current_turn == 1 and b.player2.bonus_turns == 1, "bonus awarded to recipient")
	await b.play_item(CARD)
	check(b.current_turn == 1 and b.player2.bonus_turns == 0, "recipient plays bonus turn")
	await b.play_item(SECOND)
	check(b.current_turn == 0, "bonus turn eventually passes")
	await dispose(b)

	b = await fresh_battle()
	b.player2.preferences[CARD] = {"category": "disliked", "rank": 3}
	b.available_effects = {14: b.effects_pool[14]}
	await b.play_item(CARD)
	check(b.current_turn == 0 and "skip_turn" not in b.player2.active_buffs, "enemy skip consumed automatically")
	await dispose(b)

	b = await fresh_battle()
	b.player1.pool = [manager.get_item(CARD)]
	b.player2.pool.clear()
	b.available_effects = {10: b.effects_pool[10]}
	await b.play_item(CARD)
	check(b.state == b.BattleState.WAITING_FOR_RECLAIM and b.reclaim_panel.visible, "reclaim before exhaustion")
	b.reclaim_card("missing")
	check(b.state == b.BattleState.WAITING_FOR_RECLAIM, "invalid reclaim stays pending")
	b.reclaim_card(CARD)
	check(b.player2.has_item(CARD) and b.current_turn == 1, "neutral reclaim belongs to opponent")
	check(b.player2.pool[0].name == "Margherita Pizza", "returned display name preserved")
	await dispose(b)

	b = await fresh_battle()
	b.player1.hp = 50
	b._apply_effect(b.effects_pool[21], b.player1, b.player2)
	for id in [6, 7, 8, 9]:
		b._apply_effect(b.effects_pool[id], b.player1, b.player2)
	check(b.player1.hp == 50 and b.player1.max_hp == 106, "all healing observes no-heal")
	await b.play_item(CARD)
	check("no_heal" not in b.player1.active_buffs, "healing block expires after recipient turn")
	b.player1.max_hp = 150
	b._apply_effect(b.effects_pool[8], b.player1, b.player2)
	check(b.player1.hp == 50, "max HP cap does not grant free heal")
	b.player1.setup({}, manager.items)
	check(b.player1.hp == 100 and b.player1.max_hp == 100 and b.player1.last_effect.is_empty(), "player reset clears effects and max HP")
	await dispose(b)

func test_balance_limits() -> void:
	var b = await fresh_battle()
	for category in ["disliked", "liked"]:
		var previous = 100
		for rank in range(1, 8):
			var power: int = b._calculate_hp({"category": category, "rank": rank})
			check(power > 0 and power < previous, "%s rank %d has decreasing positive power" % [category, rank])
			previous = power
	for id in [1, 3, 4, 5]:
		b._apply_effect(b.effects_pool[id], b.player1, b.player2)
	check(b._apply_damage_modifiers(b.player1, 28) == 60, "stacked damage capped at 60 HP")
	check(b._apply_damage_modifiers(b.player1, 10) == 10, "all stacked modifiers consumed")
	for id in [1, 3, 4, 5, 18]:
		b._apply_effect(b.effects_pool[id], b.player1, b.player2)
	check(b._apply_damage_modifiers(b.player1, 28) == 0, "miss overrides full stack")
	check(b._effect_count({"category": "disliked", "rank": 1}) == 2, "rank one effect budget")
	check(b._effect_count({"category": "neutral", "rank": 7}) == 1, "all neutral ranks have one effect")
	manager.reduce_motion = true
	b.animation_duration = 0.05
	b.player2.preferences[CARD] = {"category": "disliked", "rank": 1}
	await b.play_item(CARD)
	check(b.player2.hp == 70 and b.hp_bar_p2.value == 70, "reduced motion preserves combat and exact HP")
	check(b.played_cards.get_child(0).position == Vector2.ZERO, "reduced motion skips card travel")
	manager.reduce_motion = false
	await dispose(b)

func test_effect_ownership() -> void:
	# Fixed 20-damage probe isolates recipient routing from rank balance.
	var expected = {25: 16, 1: 40, 2: 25, 3: 26, 4: CardBalance.DAMAGE[0], 5: 30, 16: 10, 17: 15, 18: 0}
	for turn in [0, 1]:
		for category in ["disliked", "liked", "neutral"]:
			for id in expected:
				var b = await fresh_battle()
				b.current_turn = turn
				var attacker = b.get_current_player()
				var defender = b.get_opponent()
				var beneficial = id < 16
				var goes_to_attacker = (category == "disliked" and beneficial) or (category == "liked" and not beneficial)
				var owner = attacker if goes_to_attacker else defender
				var other = defender if goes_to_attacker else attacker
				var key = b.effects_pool[id].effect_key
				b.resolve_effects([id], category, attacker, defender)
				var context = "P%d %s effect %d" % [turn + 1, category, id]
				check(key in owner.active_buffs and key not in other.active_buffs, context + " assigned to correct player")
				check(b._apply_damage_modifiers(other, 20) == 20 and key in owner.active_buffs, context + " opponent cannot use or consume modifier")
				check(b._apply_damage_modifiers(owner, 20) == expected[id], context + " modifies recipient outgoing damage")
				check(key not in owner.active_buffs and b._apply_damage_modifiers(owner, 20) == 20, context + " consumed exactly once")
				await dispose(b)
			# Reflection transfers ownership, not just the effect message.
			for id in [1, 16]:
				var b = await fresh_battle()
				b.current_turn = turn
				var attacker = b.get_current_player()
				var defender = b.get_opponent()
				var recipient = attacker if ((category == "disliked" and id == 1) or (category == "liked" and id == 16)) else defender
				var reflected = defender if recipient == attacker else attacker
				recipient.reverse_next_effect = true
				b.resolve_effects([id], category, attacker, defender)
				check(not recipient.reverse_next_effect and recipient.active_buffs.is_empty(), "reflection clears original recipient P%d %s" % [turn + 1, category])
				check(b._apply_damage_modifiers(reflected, 20) == expected[id], "reflected modifier belongs to new recipient")
				await dispose(b)
		# Real consecutive turns: a liked-card buff goes to the defender.
		var b = await fresh_battle()
		b.current_turn = turn
		var attacker = b.get_current_player()
		var defender = b.get_opponent()
		attacker.hp = 70
		defender.hp = 70
		defender.preferences[CARD] = {"category": "liked", "rank": 1}
		attacker.preferences[CARD] = {"category": "disliked", "rank": 7}
		b.available_effects = {1: b.effects_pool[1]}
		await b.play_item(CARD)
		check("dmg_mult" in defender.active_buffs and attacker.active_buffs.is_empty(), "liked card grants defender next attack buff")
		var defender_hp: int = defender.hp
		await b.play_item(CARD)
		check(attacker.hp == 70 - 2 * CardBalance.DAMAGE[6] and defender.hp == defender_hp, "recipient next actual attack damages the other player")
		check(defender.active_buffs.is_empty(), "actual attack consumes defender buff")
		await dispose(b)
	var b = await fresh_battle()
	b._apply_effect(b.effects_pool[1], b.player1, b.player2)
	b._apply_effect(b.effects_pool[15], b.player1, b.player2)
	check(b._apply_damage_modifiers(b.player2, 20) == 20 and b._apply_damage_modifiers(b.player1, 20) == 40, "pool swap does not transfer damage buff ownership")
	b.player1.pool.clear()
	b.player2.pool = [manager.get_item(CARD)]
	b.player1.hp = 40
	b.player2.hp = 60
	b._finish_turn()
	check(b.state == b.BattleState.WAITING_FOR_CARD, "one empty pool does not end battle")
	await b.play_item(CARD)
	check(b.state == b.BattleState.BATTLE_OVER and b.win_screen.title_label.text == "Player 2 wins!", "both pools exhausted: lower HP loses")
	await dispose(b)

func test_forms() -> void:
	var form = load("res://scenes/preferenceForm.tscn").instantiate()
	root.add_child(form)
	form.setup(1, manager.items)
	await process_frame
	await process_frame
	check(form.get_node("Layout").get_global_rect().end.x <= 1280, "form fits viewport width")
	check(form.get_node("Layout").get_global_rect().end.y <= 720, "form fits viewport height")
	check(form.pool_grid.get_parent().get_global_rect().end.x <= 1280, "pool scroll fits viewport")
	form._on_confirm()
	check(not form.submitted, "invalid preference submission blocked")
	var first = form.pool_grid.get_child(0)
	var first_id = first.item_id
	form._drop_card_into(first, form.like_list, Vector2.ZERO)
	form._start_drag(form.pool_grid.get_child(0), Vector2.ZERO)
	form.time_remaining = 0.01
	form._process(0.1)
	check(form.like_list.get_child(0).item_id == first_id, "timeout preserves selected ranks")
	check(form.dragging_card == null and form.drag_ghost == null, "timeout cancels drag")
	check(not form.confirm_btn.disabled and form._build_preferences().size() == 21, "timeout fills valid preferences")
	var swapped = form.dislike_list.get_child(0)
	form._drop_card_into(swapped, form.like_list, Vector2(-10, -10))
	form._update_all_ranks()
	form._check_confirm_valid()
	check(form.like_list.get_child_count() == 7 and form.dislike_list.get_child_count() == 7, "full categories swap without overflow")
	check(form._build_preferences().size() == 21 and not form.confirm_btn.disabled, "swap preserves complete unique deck")
	form._start_drag(swapped, Vector2.ZERO)
	form._on_randomize()
	check(form.dragging_card == null and form._build_preferences().size() == 21, "randomize during drag is safe")
	form._on_confirm()
	check(form.submitted and form.confirm_btn.disabled, "submission locks form")
	form.setup(2, manager.items)
	check(not form.randomize_btn.disabled and form.pool_grid.get_child_count() == 21, "form reuse resets controls and cards")
	await dispose(form)

func test_matches() -> void:
	# Seeded complete matches exercise combinations of all effects and pool changes.
	for seed_value in range(40):
		seed(seed_value)
		var b = await fresh_battle()
		b._setup_preview_data()
		var moves = 0
		while b.state != b.BattleState.BATTLE_OVER and moves < 200:
			if b.state == b.BattleState.WAITING_FOR_RECLAIM:
				b.reclaim_card(b.played_cards_list[0])
			else:
				var player = b.get_current_player()
				if player.pool.is_empty():
					check(false, "seed %d stalled on empty pool" % seed_value)
					break
				await b.play_item(player.pool.pick_random().id)
			moves += 1
		check(b.state == b.BattleState.BATTLE_OVER, "seed %d completes" % seed_value)
		check(b.hp_bar_p1.value == b.player1.hp and b.hp_bar_p2.value == b.player2.hp, "seed %d HP display" % seed_value)
		await dispose(b)

func test_scene_flow() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	check(main.current_form == null and main.current_screen == "menu", "match starts at main menu")
	main._show_customization()
	check(main.form_container.get_child(0).name_fields.size() == 2, "customization shows both players")
	main._start_match()
	main.current_form._on_randomize()
	main.current_form._on_confirm()
	main._pass_device_to_player_two()
	check(main.current_form == null, "handoff ignores confirmation click")
	await create_timer(0.6).timeout
	main._pass_device_to_player_two()
	check(main.form_container.get_child_count() == 1 and main.current_form.current_player == 2, "handoff removes prompt")
	main.current_form._on_randomize()
	main.current_form._on_confirm()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://scenes/battle.tscn", "both forms start battle")
	current_scene._end_battle("Player 1", "Test")
	current_scene.win_screen._on_restart_pressed()
	await process_frame
	await process_frame
	check(current_scene.current_screen == "menu" and current_scene.current_form == null and manager.prefs_p1.is_empty() and manager.prefs_p2.is_empty(), "rematch returns to menu and resets preferences")

func test_shared_effect_pool() -> void:
	var b = await fresh_battle()
	b.available_effects = {1: b.effects_pool[1]}
	await b.play_item(CARD)
	check(b.available_effects.is_empty() and b.used_effect_ids.has(1), "trigger removes effect from shared pool")
	await b.play_item(CARD)
	check(b.effect_history.size() == 1 and b.player1.active_buffs.is_empty(), "second player cannot draw first player's spent effect")
	b._return_card(CARD, b.player1)
	await b.play_item(CARD)
	check(b.effect_history.size() == 1, "returned card cannot replenish spent effects")
	await dispose(b)
	b = await fresh_battle()
	b._reset_effect_pool()
	for player in [b.player1, b.player2]:
		player.hp = 150
		player.max_hp = 150
	var drawn: Array = b.draw_effect(100)
	check(drawn.size() == 30 and b.draw_effect(1).is_empty(), "one shared supply reserves each effect once and never refills")
	b.resolve_effects(drawn, "neutral", b.player1, b.player2)
	check(b.used_effect_ids.size() == 30 and b.effect_history.size() == 30, "all 30 unique effects resolve once")
	var hp_before: int = b.player2.hp
	var cards_before: int = b.player2.pool.size()
	b.resolve_effects(drawn, "neutral", b.player1, b.player2)
	check(b.player2.hp == hp_before and b.player2.pool.size() == cards_before and b.effect_history.size() == 30, "replayed effect IDs cannot resolve twice")
	b._reset_effect_pool()
	check(b.available_effects.size() == 30 and b.used_effect_ids.is_empty() and b.effect_history.is_empty(), "new match restores effect supply and clears journal")
	await dispose(b)

func test_customization() -> void:
	manager.set_profile(0, "  Nova  ", 2, 3)
	manager.set_profile(1, "", 99, -10)
	check(manager.player_name(0) == "Nova" and manager.player_name(1) == "Player 2", "names trim and empty names get defaults")
	check(manager.profiles[1].avatar == 3 and manager.profiles[1].color == 0, "avatar and color values are bounded")
	var path = "C:/Users/devil/AppData/Local/Temp/taste-duel-profile-test.cfg"
	check(manager.save_profiles(path) == OK, "profiles save successfully")
	manager.reset_profiles()
	manager.load_profiles(path)
	check(manager.player_name(0) == "Nova" and manager.profiles[0].avatar == 2 and manager.profiles[0].color == 3, "profiles restore names and sprite customization")
	var b = await fresh_battle()
	check(b._player_name(b.player1) == "Nova" and b._portraits[0].avatar_index == 2, "battle uses customized name and sprite")
	b.select_item(CARD)
	check(b.selected_item == CARD and b.player1.pool.size() == 21 and b._play_button.visible, "selection previews without spending card")
	b._open_settings()
	b._play_button.pressed.emit()
	check(b.player1.pool.size() == 21, "settings overlay blocks a focused play button")
	b._settings_panel.hide()
	b._show_history()
	b.select_item(SECOND)
	check(b.selected_item == CARD, "journal blocks underlying card selection")
	b._history_panel.hide()
	b._play_button.pressed.emit()
	check(b.player1.pool.size() == 20 and b._play_button.disabled, "play confirmation spends exactly one card and disables action")
	b._end_battle("Player 1", "Test")
	check(b.win_screen.title_label.text == "Nova wins!", "custom name shown in results")
	await dispose(b)
	manager.reset_profiles()
