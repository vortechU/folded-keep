extends Node
## Global signal bus. Gameplay emits, UI/audio listen (and vice versa for requests).

# state -> UI
signal ink_changed(ink: int)
signal keep_hp_changed(hp: int, max_hp: int)
signal wave_changed(wave: int, total: int)
signal phase_changed(phase: String) # "build", "wave", "victory", "defeat"
signal banner(text: String)

# gameplay moments (for audio / juice)
signal slammed(crushes: int)
signal fold_lesson_changed(guide: Dictionary) # tower, enemy, grab, pointer, dragging, ready
signal tower_crush_landed
signal map_inspection_changed(active: bool)
signal battle_report_ready(report: Dictionary) # final totals before victory/defeat
signal unit_crushed(unit: Node)
signal building_placed(kind: String, pos: Vector2)
signal keep_hit
signal keep_slammed
signal boss_spawned
signal torn(pos: Vector2) # the map ripped open
signal flung(unit: Node) # a unit was flipped off the edge of the map

# royal decrees (between waves) — see scripts/game/decrees.gd
signal decree_offered(ids: Array) # gameplay -> UI: show these cards, pick one
signal decree_chosen(id: String) # UI -> gameplay
# a new enemy kind appears for the first time this run (UI may show an intro card)
signal enemy_introduced(kind: String)
# Duel of Champions (scripts/duel/duel.gd): the map is frozen (tree paused) in between
signal duel_started(boss: String) # "warlord" or "driver"
signal duel_finished(won: bool)

# UI -> gameplay requests
signal build_requested(kind: String)
signal start_wave_requested
signal restart_requested
