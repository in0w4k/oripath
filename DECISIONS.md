# DECISIONS.md

## Week 10 — Enemy AI

- **2026-11-11** — Ported chapter 4 arena into OriPath and split enemies into 3 FSM scripts (`NurseEnemy`, `OrderlyEnemy`, `SnowmanShooter`) under `Enemy -> Hazard`.
- **2026-11-12** — Enemies got stuck vibrating on wide dividing walls. Replaced dividers with 4 pillars and switched wall avoidance in `enemy.gd` to normal-tangent sliding with `avoid_side` memory.
- **2026-11-13** — Snowman and Nurse only attacked point-blank because `query.exclude.append()` in Godot 4 modifies a copy and dropped the player RID. Fixed by building `exclude_rids: Array[RID]` first and assigning `query.exclude = exclude_rids`.
- **2026-11-13** — Fixed bullets all showing `"ПИУ!"` by matching `shot_words` with `shot_sounds` in `weapon.gd` and adding `setup()` in `bullet.gd`. Split enemy/pickup spawning in `spawner.gd` with wave caps and a `SpawnPortal` telegraph.

## Week 11 — Data and Saves

- **2026-11-17** — Moved enemy, player, weapon, and pickup balance numbers out of scripts into Godot `Resource` assets (`EnemyStats`, `PlayerStats`, `WeaponStats`, `PickupStats`) in `res://data/`. Kept runtime `health` on each enemy instance so shared `.tres` assets never mutate.
- **2026-11-18** — Built 3 levels (`level_01.tres`, `level_02.tres`, `level_03.tres` — Survive 35s, Eliminate 6 enemies / 60s, Survive 50s) that all load inside one scene (`world_4.tscn`) from `LevelData` and `WaveData`.
- **2026-11-19** — Replaced `settings.cfg` with atomic JSON saves (`user://save.json` via `save.tmp`) in `SaveSystem` + `SaveData`, returning defaults on missing/empty/broken JSON and saving on level clear, settings change, and app pause/focus-out.
- **2026-11-19** — Added locked/unlocked level buttons and Reset Progress confirm modal in `ui/main_menu.gd`. Fixed reset recreating `save.json` immediately through slider signals by using `set_value_no_signal()` and `set_pressed_no_signal()`.
