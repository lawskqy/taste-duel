# Taste Duel - knockout-focused balance

This revision responds to playtesting in which too many matches exhausted their cards. The goal is roughly 90% knockouts under random play, while retaining HP decisions and occasional draws. The simulation is a reproducible design check, not a promise about human win rates.

## Rank values implemented

Each round samples 21 cards from the selected 50 item theme pool. Both players rank that shared draw into **7 disliked, 7 neutral, and 7 liked**. The opponent's private ranking determines power; item identity has no intrinsic damage value.

| Opponent's rank | Disliked: damage | Liked: healing | Effects drawn |
| --- | ---: | ---: | ---: |
| 1 | 30 | 10 | 2 |
| 2 | 27 | 8 | 2 |
| 3 | 24 | 7 | 1 |
| 4 | 21 | 6 | 1 |
| 5 | 18 | 5 | 0 |
| 6 | 15 | 4 | 0 |
| 7 | 12 | 2 | 0 |

Neutral cards at every rank still change no HP and draw one effect. Rank 1 is the strongest preference. Setup previews and combat share `scripts/combat/CardBalance.gd`.

Attack priority remains disliked #1 through #7, then situational neutral cards. Liked cards heal the opponent; absent a special interaction, #7 is the least costly and #1 the most costly. Effects, healing block, and information about the opponent can change that order.

## Why this ends more games by knockout

Across seven disliked cards, base damage increases from **133 to 147**. Across seven liked cards, healing decreases from **56 to 42**. The full-pool base damage surplus increases from **77 to 105 HP**, before effect modifiers, overhealing, discards, and repeated cards. Average disliked damage is 21; average liked healing is 6.

The top three unmodified attacks total **81**, so they cannot by themselves kill a full-health player. The top four total **102**, making an informed sequence lethal. Players still start at 100 HP.

Healing effects are also reduced:

| Effect | Previous | Current |
| --- | ---: | ---: |
| Small heal | 10 HP | 8 HP |
| Large heal | 24 HP | 16 HP |
| Max HP increase and corresponding heal | 10 HP | 6 HP |
| Missing-HP heal | 25% | 15%, rounded down |
| Strong damage multiplier | x1.5 | x2 |
| Critical base | 28 | 30 |
| Maximum modified card hit | 48 | 60 |

Other damage effects remain x1.25, +6 flat damage, and +50% damage. Damage penalties remain x0.5, x0.75, and a miss. Instant negative effects still deal 10 HP, 20% current HP, or 10% maximum HP. Effects are removed from the shared match pool once drawn; the draw counts were retained to avoid adding more random tempo swings.

Next-hit calculation: critical base if present, multiplier, +6 flat bonus, then +50%, flooring after each multiplication; a miss overrides the result. Clamp the card hit to 60. This cap is per damaging card, not a cap on separate effects or extra turns combined. Identical modifier keys replace each other instead of stacking.

## Effect ownership - explicit rules and tests

| Card played against opponent's ranking | Good effect recipient | Bad effect recipient |
| --- | --- | --- |
| Disliked | Attacker | Opponent |
| Liked | Opponent | Attacker |
| Neutral | Opponent | Opponent |

A modifier belongs to its **recipient**, independent of who drew it. It changes that recipient's next outgoing damaging card. It never increases incoming damage to that person, never changes the other player's attack, and is not consumed by the other player's turn. Healing and neutral plays preserve it. Effects drawn from a card resolve after that card's base damage, so a new damage buff applies to a future attack.

Example: Player 1 plays a disliked card and draws x2. Player 1 keeps x2 through Player 2's turn, then their 12-damage card deals 24 to Player 2. If Player 1 instead plays a liked card and draws x2, Player 2 receives it and their next damaging card hits Player 1 harder.

Reflection transfers the next assigned effect to the other player once. The former copy effect is now a unique maximum-HP penalty, so no effect is replayed. Swapping card pools does not swap existing player buffs. The battle log identifies attacker, target, final damage, and base damage when modified; active effects are labeled with their owner's name and update immediately after resolution.

Regression coverage includes every damage modifier for both attacking players and all three categories; opposing attacks cannot consume a buff; one-time consumption; reflected modifiers; an actual liked-card/defender-counterattack sequence in both directions; and pool-swap ownership.

## Effect priorities

These are contextual design estimates, not measured per-effect win rates.

| Priority | Effects | Reference value |
| --- | --- | --- |
| Highest tempo | Extra play, enemy skips, recipient skips, enemy extra play | An extra informed attack or denied turn can decide a match. |
| High damage / prevention | x2, miss | At 21 base damage: 42 damage or an entirely canceled hit. |
| High with knowledge | Reclaim chosen discard, return played card | Can repeat a known disliked card. |
| Medium | +50%, critical base 30, heal 16 | At 21 base: 31 or 30 damage; healing is capped by missing HP. |
| Modest | x1.25, +6 damage, heal 8, max HP +6, heal 15% missing | At 21 base: 26 or 27 damage. Missing-HP heal restores 7 at 50 missing HP. |
| Disruption | x0.5/x0.75, instant HP loss, discard/destroy | Depends on the attack or cards denied. |
| Situational | Duplicate random card, swap pools, healing block, reflection | Depends on state and information; no universal ranking. |

The original good/bad routing categories for swap and reflection are preserved. The category determines who receives an effect; it does not guarantee that the outcome benefits or harms them.

## Shared effect pool and current outcomes

Both players now draw from **one pool of 30 effects**. Every drawn ID leaves the pool immediately. A used-ID guard also prevents duplicate resolution. The pool never refills during a match, even when cards are reclaimed, returned, or duplicated. A new match resets both the pool and the public journal. Distinct effects may still produce similar outcomes (for example different damage modifiers), but the same effect ID cannot trigger twice.

The previous implementation gave each player an independent copy of the pool. It also had a duplicate one-card discard entry and a copy effect. Effect 25 is now **next damage -4**; effect 30 is now **lose 6 maximum HP**, clamping current HP to the new cap and keeping maximum HP at least 1. Reflection moves the one assignment; it does not create another copy.

The current shared-pool production run (`tests/reports/balance_shipped.json`) has 400 seeds per policy:

| Policy | Knockouts | Unequal HP decisions | Draws | Mean plays |
| --- | ---: | ---: | ---: | ---: |
| Random cards | 378 (94.5%) | 20 (5%) | 2 (0.5%) | 25.015 |
| Known rankings / highest base damage | 400 (100%) | 0 | 0 | 6.6225 |

No match stalled. First-player wins were 223/400 and 275/400 respectively. Existing damage/healing values were retained: the shared pool still supports the requested knockout bias and occasional alternative endings. Sound and animation use no gameplay random draws, so cosmetic activity does not change effect selection.

## Historical tuning results (before the shared-pool change)

400 seeds per policy per candidate. Both players use the same policy. Random play chooses any remaining card; the informed stress test knows the full rankings and greedily maximizes signed base HP change without planning effects. Both reclaim the first discard. A play is one card action, not a full two-player round. Trials terminate at 200 plays if stalled.

| Configuration / random policy | Knockouts | HP decisions including draws | Draws | Mean plays |
| --- | ---: | ---: | ---: | ---: |
| Previous balance, 7/7/7 | 277/400 (69.25%) | 123/400 | 2 | 29.91 |
| Higher damage 34..16, 7/7/7 | 390/400 (97.5%) | 10/400 | 0 | 20.29 |
| 8 disliked / 5 neutral / 8 liked, 32..11 damage | 386/400 (96.5%) | 14/400 | 0 | 21.89 |
| Higher damage 32..14, 7/7/7 | 380/400 (95%) | 20/400 | 0 | 22.55 |
| **Selected: 30..12, 7/7/7** | **364/400 (91%)** | **36/400** | **1** | **24.71** |

The selected sample contains 35 unequal-HP decisions (8.75%) and one draw (0.25%). All candidates use the same reduced healing/effects except the explicitly labeled previous balance. The 8/5/8 alternative was tested; it was not necessary to achieve the knockout target. Keeping 7/7/7 preserves setup simplicity and leaves more room for the requested non-knockout endings.

Selected informed play: 400/400 knockouts, 6.63 mean plays, median 6, 10th-90th percentile 5-9. Selected random play: median 24, 10th-90th percentile 12-38. No candidate stalled. First-player wins remain 223/400 under random play and 273/400 under fully informed play, so opening advantage still merits human testing; alternating the starter across rematches is a future experiment.

The table above records the earlier two-pool implementation, not a claim about the current pool rules. Candidate profiles now evaluate their rank/effect values against the current shared-pool engine. Run `godot --headless --path . --script res://tests/balance_report.gd -- shipped` to exercise the actual production rules with presentation disabled. Candidate runs can use `-- previous`, `-- pressure_7`, `-- pressure_8`, `-- moderate_7`, or `-- gentle_7`. With no filter, all profiles run. Results go to `tests/reports/balance_<profile>.json` for filtered runs or `tests/reports/balance_results.json` for a full run. The initial four-profile comparison and the separate gentle profile are retained in the repository; `tests/reports/balance_v1_results.json` is the historical first-pass report.

## Ending rules retained

A player reaching 0 HP loses immediately; later effects cannot revive them. If only one pool is empty, the other player continues playing. Only when **both** pools are exhausted is remaining HP compared: **higher HP wins, lower HP loses, equal HP draws**. Pending reclaim choices resolve before exhaustion is checked. Draw and unequal-HP endings are covered explicitly by regression tests even when uncommon in simulations.

## Design direction implemented

**Dark bistro tabletop:** ink background `#101B24`, slate cards `#1C2C37`, cream typography `#F4EAD6`, coral damage `#FF8C7D`, mint healing `#83DFBB`, gold effects `#EDC77F`. Explicit DMG/HP/FX labels accompany color, so meaning does not rely on color alone.

- Unified rounded panels, focus outlines, hover states, and restrained borders across setup, battle, reclaim, and results.
- Existing food illustrations rendered as warm rounded tiles with a small Godot canvas shader. No replacement artwork is required.
- Four animated, customizable SVG character sprites replace the numeric player badges and old portrait photos. Procedural table panels replace the unrelated table photo.
- Setup shows each rank's real power, with full-name and rule tooltips.
- Cards travel to the center and settle with a short scale animation; damage/healing uses radial particles, floating numbers, and animated HP bars. Low HP changes the bar to coral.
- Reduced motion disables card travel, scaling, particles, and HP tweening while retaining static numeric feedback. The preference survives rematches for the current session.
- GL Compatibility is used for this 2D game to avoid requiring a high-end rendering backend.

Suggested next design pass: a compact public history of revealed cards, keyboard-accessible preference sorting, and a two-leg match mode that alternates the starting player. Keep secret rankings hidden during battle; a global food power tier list would undermine the preference mechanic.

## Theme catalogs

`data/themes.json` contains five text catalogs of 50 items each: Food & Drink, Cities & Countries, Movies & TV, Music Artists, and Hobbies & Activities. At the start of a match, the selected catalog is shuffled and 21 distinct items are sampled once; both private ranking screens receive the same draw. Rematches draw a new sample from the same selected catalog. Existing food illustrations remain available for their matching items; all catalog items work without added images and show a short text mark in the UI.

## Customization and interaction pass

The lobby introduces the match before private ranking: two editable names, four characters, five apron colors, and sound/motion settings. Profiles are stored in `user://players.cfg` and survive app restarts and rematches. Character art is native SVG with a recoloring shader, keeping it crisp at different resolutions.

Battle now uses select-then-play with a central preview, explicit active-player halos, sprite reactions, synthesized sound cues, and projectile trails. Settings and the effect journal are modal and block underlying play, including keyboard-triggered actions. The journal lists the spent effect ID, triggering card, and named recipient; it never reveals unplayed preferences. Results show the winning customized sprite and name.
