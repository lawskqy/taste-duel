extends SceneTree

const MATCHES = 400
const PROFILES = {
	"shipped": {},
	"previous": {"damage": [28,25,22,19,16,13,10], "heal": [14,12,10,8,6,4,2], "cap": 48, "multiplier": 1.5, "small_heal": 10, "big_heal": 24, "max_hp": 10, "missing_heal": 0.25},
	"pressure_7": {"damage": [34,31,28,25,22,19,16], "heal": [10,8,7,6,5,4,2], "cap": 60, "multiplier": 2.0, "small_heal": 8, "big_heal": 16, "max_hp": 6, "missing_heal": 0.15},
	"pressure_8": {"damage": [32,29,26,23,20,17,14,11], "heal": [10,9,8,7,6,5,4,3], "cap": 60, "multiplier": 2.0, "small_heal": 8, "big_heal": 16, "max_hp": 6, "missing_heal": 0.15},
	"moderate_7": {"damage": [32,29,26,23,20,17,14], "heal": [10,8,7,6,5,4,2], "cap": 60, "multiplier": 2.0, "small_heal": 8, "big_heal": 16, "max_hp": 6, "missing_heal": 0.15},
	"gentle_7": {"damage": [30,27,24,21,18,15,12], "heal": [10,8,7,6,5,4,2], "cap": 60, "multiplier": 2.0, "small_heal": 8, "big_heal": 16, "max_hp": 6, "missing_heal": 0.15},
}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var results: Array = []
	for profile_name in PROFILES:
		if not OS.get_cmdline_user_args().is_empty() and profile_name not in OS.get_cmdline_user_args():
			continue
		for informed in [false, true]:
			var lengths: Array[int] = []
			var wins = [0, 0, 0]
			var stalled = 0
			var knockouts = 0
			var hp_decisions = 0
			for match_seed in range(MATCHES):
				seed(match_seed + 1000)
				var battle = load("res://battle.tscn").instantiate()
				battle.set_script(load("res://tests/SimulationBattle.gd"))
				root.add_child(battle)
				battle.prepare(PROFILES[profile_name])
				var moves = 0
				while battle.state != battle.BattleState.BATTLE_OVER and moves < 200:
					if battle.state == battle.BattleState.WAITING_FOR_RECLAIM:
						battle.reclaim_card(battle.played_cards_list[0])
						continue
					var pool: Array = battle.get_current_player().pool
					var item = pool.pick_random()
					if informed:
						var best_score = -1000
						for candidate in pool:
							var pref: Dictionary = battle.get_opponent().get_preference(candidate.id)
							var score: int = battle._calculate_hp(pref) * (1 if pref.category == "disliked" else -1)
							if score > best_score:
								best_score = score
								item = candidate
					await battle.play_item(item.id)
					moves += 1
				if moves >= 200:
					stalled += 1
				elif battle.end_reason == "Reached 0 HP":
					knockouts += 1
				else:
					hp_decisions += 1
				wins[0 if battle.winner_name == "Player 1" else (1 if battle.winner_name == "Player 2" else 2)] += 1
				lengths.append(moves)
				battle.free()
			lengths.sort()
			var total = 0
			for length in lengths:
				total += length
			var record = {"rules": profile_name, "policy": "known rankings, highest base damage" if informed else "random cards", "matches": MATCHES, "mean_plays": float(total) / MATCHES, "median_plays": lengths[MATCHES / 2], "p10_plays": lengths[MATCHES / 10], "p90_plays": lengths[MATCHES * 9 / 10], "p1_wins": wins[0], "p2_wins": wins[1], "draws": wins[2], "knockouts": knockouts, "hp_decisions_including_draws": hp_decisions, "stalled": stalled}
			results.append(record)
			print(JSON.stringify(record))
	var filename = "balance_results" if OS.get_cmdline_user_args().is_empty() else "balance_" + "_".join(OS.get_cmdline_user_args())
	var output = FileAccess.open("res://tests/%s.json" % filename, FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	quit()
