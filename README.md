# Taste Duel

A local two-player game about knowing the other player's preferences. Pick one of five themes: Food & Drink, Cities & Countries, Movies & TV, Music Artists, or Hobbies & Activities. Each theme has 50 text entries. The game samples 21 unique items at random; both players rank the exact same draw into 7 liked, 7 neutral, and 7 disliked cards, then play against the other player's private rankings.

Open `project.godot` in Godot 4.7.1 and run the project. Choose a theme, player names, one of four animated characters, and apron colors in the lobby. These choices and sound/motion settings are saved locally. Every rematch draws a fresh set of 21 from that theme. Enter the kitchen to rank privately. Drag cards to sort or reorder them; dropping onto a full category swaps cards. Scroll to reach every card. The two-minute setup timer fills only unsorted slots, preserving existing choices, then lets the player confirm. Pass the device for Player 2's setup.

## Current rules

- Both players start with 100 HP and identical copies of the round's 21 sampled items.
- A disliked card damages the opponent: ranks 1–7 deal 30, 27, 24, 21, 18, 15, or 12 HP.
- A liked card heals the opponent: ranks 1–7 restore 10, 8, 7, 6, 5, 4, or 2 HP.
- Neutral cards change no HP and draw one effect. Liked/disliked ranks 1 through 7 draw 2, 2, 1, 1, 0, 0, or 0 effects respectively.
- Both players share one 30-effect pool. Drawing removes an effect immediately, and a triggered effect ID cannot resolve a second time in that match. Returned cards do not restore effects. Only a new match refills the pool.
- Disliked cards give good effects to the attacker and bad effects to the opponent. Liked cards reverse that assignment. Neutral cards give either kind to the opponent.
- Reaching 0 HP ends the match immediately, including self-inflicted damage. Empty pools are skipped automatically. When both pools are empty, higher HP wins; equal HP is a draw.

## Effect rules

Effects resolve on their named recipient:

- **Damage modifiers:** consumed together on the next damaging attack, never on healing or neutral cards. Critical sets base damage to 30; multiplier, +6 flat bonus, and +50% damage then apply, capped at 60 damage per card hit. A miss overrides the result. Repeated modifiers with the same key replace that key's previous value.
- **Healing block:** blocks every source of healing through the recipient's next turn that starts with the block. If applied during their own turn, it remains through their following turn. A skipped turn also expires the block. Increasing max HP still increases the cap, but cannot bypass the healing block. Max HP is capped at 150.
- **Extra turn:** belongs to the effect's recipient. They play an additional card after their normal turn. “Enemy gets an extra turn” awards it to the recipient's opponent. Bonus turns stack; a skip consumes one turn and does not require clicking a card.
- **Reclaim:** the recipient chooses one card from the shared discard pile, or skips. Pending reclaims finish before checking pool exhaustion.
- **Return played card:** returns the exact card just played to the recipient. It cannot return that same copy twice.
- **Discard versus destroy:** lost/discarded cards enter the shared pile and can be reclaimed. Destroyed cards cannot.
- **Distinct negative effects:** effect 25 now reduces next damage by 4; effect 30 reduces maximum HP by 6 (minimum max HP 1, current HP clamped to the new cap). These replace the duplicate discard and copy effects.
- **Reverse next effect target:** reflects the next effect assigned to the recipient onto the other player, then expires. Reflection happens once per effect; it does not swap existing buffs or their values.
- Effects resolve in draw order. A knockout stops later effects. The played card leaves its original pool before swap, return, discard, or duplicate effects run.

## Themes

Theme text and descriptions live in `data/themes.json`, with 50 entries each for food/drink, cities/countries, movies/TV, music artists, and hobbies/activities. The first 21 food IDs keep their existing art. Cards without existing art use a text symbol and need no image files. Each round samples 21 distinct cards from one theme; both players share that same sample. Adding a theme does not change combat rules. Keep item IDs unique across all themes.

## Verification

Run the regression suite from the project directory:

```sh
godot --headless --path . --script res://tests/run_tests.gd
```

Use your Godot executable's full path if it is not on PATH. The suite checks combat, all 30 effects, duplicate-card returns, setup validation, timer/drag interactions, 40 seeded complete matches, and setup-to-rematch scene transitions. It exits nonzero if a check fails.

## Balance and presentation

See [BALANCE_AND_DESIGN.md](BALANCE_AND_DESIGN.md) for rank tables, effect tiers, calculations, simulation results, and the design direction. Combat now has card travel, impact particles, floating HP feedback, and animated health bars. Reduced motion is available in setup and battle.

Run `godot --headless --path . --script res://tests/balance_report.gd` to compare the previous balance, four candidate balances, and the shipped game. Append `-- shipped` to run only the production rules; results go to `tests/balance_shipped.json`. With the shared pool, the current game produced 378 knockouts, 20 unequal-HP decisions, and 2 draws in 400 seeded random-play matches.

Damage effects belong to the named recipient and change only their next outgoing damaging card. Drawing an effect does not necessarily make you its recipient: disliked, liked, and neutral cards route effects differently as described above. The battle log shows the attacker and target explicitly.

## Player experience

- Four original SVG character sprites: Pepper the chef, Miso the fox, Byte the robot, and Mochi the cat; five apron colors.
- Saved player names and customization appear in ranking setup, battle, effect ownership, and results. Rematches keep profiles and clear match state.
- Select a card to preview it, then press **Play this card**. The preview does not expose your opponent's secret ranking.
- Animated active-player halos, idle movement, attack reactions, projectile trails, impact particles, healing numbers, and HP bars. Reduced motion suppresses movement while keeping the outcome visible.
- Synthesized sound cues with a sound toggle; fullscreen and reduced motion controls in Settings. Escape opens/closes settings and closes the journal.
- The Effect Journal records each spent effect ID, its triggering card, and its recipient. The shared-pool counter makes exhaustion visible.
- Settings and journal overlays block underlying card input. Names are limited to 16 characters; empty names use defaults and identical names show player-slot suffixes.
