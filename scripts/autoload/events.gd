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
signal unit_crushed(unit: Node)
signal building_placed(kind: String, pos: Vector2)
signal keep_hit
signal keep_slammed
signal boss_spawned

# UI -> gameplay requests
signal build_requested(kind: String)
signal start_wave_requested
signal restart_requested
