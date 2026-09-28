# Folded Keep — Design & Tech Spec

> **Source of truth.** Every agent (human or AI) reads this before touching the project.
> If you change a rule, change it here too. Status: **v0.1 — fold prototype in progress.**

## Pitch
You defend your castle by **folding the map it's drawn on.** Drag any edge of the parchment
inward to fold it, then let go: the flap **slams** face-down, and whatever is inked on the flap
hits whatever lies underneath. Your castle layout *is* your arsenal.

## Jam constraints (SlapJam AI #1)
- 48h, **2026-09-28 → 2026-09-30**. Theme: **Castles**. Judged on **Fun, Visual Appeal, Theme**.
- **Mobile portrait**, touch controls. **HTML5 web build** on itch.io. Made with AI.
- Judges may play with a **mouse on desktop**. Every interaction must work with a single pointer.

## The laws (core rules)
1. **The map** is a 360×640 parchment. Terrain, roads, buildings and units are all "printed" on it.
2. **Fold:** press within **28 px of a map edge** and drag inward. The fold line is the perpendicular
   bisector of the grab point **G** and the pointer **P**. The **flap** is the side containing G.
   Releasing after a drag shorter than 24 px cancels the fold.
3. **Slam** (on release):
   - A unit in the **landing zone** (under the flap) gets hit by what's printed on the flap at its
     mirrored point:
     - a **heavy** building (tower, wall, keep) → **CRUSHED** (killed, ink splat)
     - blank paper → **SLAPPED** (stunned 1.5 s, knocked back)
   - A unit **on the flap** whose mirrored point lands on the map is **flipped**: it's moved to
     the mirrored position and stunned for 1 s. You can throw enemies around, but careful, you can
     also throw them toward your Keep.
   - **Friendly fire:** your own units follow exactly the same rules.
   - Buildings are never damaged by folds. They are the hammer.
   - **While dragging:** time slows to 45%, the flap turns translucent so you can aim through it,
     and markers preview every outcome (red ✕ = crush, gold ring = slap, blue dashed arrow = flip).
     The flap's back shows its ink faintly, mirrored, so you can see where the towers will land.
   - Impact juice: hit-stop (70 ms + extra per crush) and screen shake. Crushed units leave
     **permanent ink splats**, so the map remembers every battle.
4. The map **unfolds automatically** 0.35 s after the slam.
5. **Creases & tears:** each slam leaves a visible crease line. Where a new crease crosses two
   old creases close together (three folds meeting), the map **rips open** into a hole (a red
   rip marker previews it while dragging). Buildings on the rip are lost (the Keep's area never
   tears). Units that walk into a hole fall through (enemies still pay out ink). Each hole
   swallows 3 units, then it's stitched shut with a patch. Tuning in `fold_controller.gd`.
6. **Enemies** (red ink) walk the roads from the top edge toward the **Keep** (bottom center).
   Reaching the Keep damages it. Keep HP 0 = defeat.
7. **Build phase** between waves: spend **Ink** (earned from kills) to stamp buildings on
   non-road paper.
8. **Waves:** 12 waves (mid-boss at 6, final boss at 12, see "12-wave run"). Survive all of them = victory. Endless mode is a stretch goal.

### HUD layout rules (the map is the whole screen, so UI must not block folding)
- The map's **edges are the controls**. During a wave, no UI may block input within 28 px of any
  edge (use `mouse_filter = IGNORE` on anything overlapping the edges).
- **Never cover the Keep** (x 140–220, y 545–625), and keep the bottom edge grabbable for the Keep Slam.
- Top bar: at most 22 px tall, input-transparent. The build bar exists only in the build phase.
- Banners must be input-transparent and must not dim the map during waves.

### Buildings (blue ink, player)
| Building | Heavy? | Role |
|---|---|---|
| Keep | yes | Your castle. Fold the bottom edge up for a **Keep Slam** (huge area). Costs 1 Keep HP during a wave, never drops you below 1. |
| Tower | yes | The basic hammer. Cheap. |
| Wall | yes | Heavy *and* blocks the road. Enemies stop to bash it. |
| Barracks | no | 5 ink. Keeps 2 blue knights on the nearest road (respawn 6 s in waves). Knights pin enemies in melee, which sets up folds, but your folds hurt them too. |

### Enemies (red ink)
| Enemy | Behavior |
|---|---|
| Grunt | Walks the road. 1 slap stuns, any crush kills. |
| Runner | Fast, fragile. Dies from a slap too. |
| Brute | Slow. Slaps do nothing; only a crush kills. |
| Mid-boss: Iron Warlord (`warlord`) | Wave 6. Needs 2 crushes, ignores slaps, hacks walls (4/hit), knights can't kill him, deals 4 Keep damage, 8 ink. |
| Boss: Siege Ram | Wave 12 (final). Needs 3 crushes, ignores slaps, breaks walls in one hit, deals 5 Keep damage. Flipping it throws it back up the road. |

### Royal Decrees (done)
After each cleared wave the King offers 3 of 12 decrees (`scripts/game/decrees.gd`), pick 1, it lasts
the run. Effects live in `fold_controller.gd` / `main.gd` (`Decrees.has(id)`). UI: Helper task #20.

### Fling rule (done)
A unit on the flap whose mirrored spot falls **off the map** is **flung off the table** (dies,
"OFF THE MAP!", gold arrow in the aim preview). Happens with big diagonal folds. Bosses can't be flung.
`Unit.is_boss()`, `Unit.is_flying()` exist.

### Fold-aware enemies (done, task #22b) — enemies that fight the MAP
| Enemy | Kind id | Behavior |
|---|---|---|
| Pin-Bearer | `pinner` | Leaves the road, walks to the nearest map **corner** and hammers in a giant nail. While he lives, folds can't be grabbed within ~140 px of that corner (grab is refused with a red shake/flash on the pin). Doesn't attack the Keep. 2 slaps or a crush kill him. Reward 3. From wave 3. |
| Crow Rider | `flyer` | Flies in a straight line from the top toward the Keep, ignoring roads, walls and knights. **Can't be crushed or slapped** (the flap passes under it); only **flipped** (sent back) or **flung** off the map. From wave 4. |
| Ink Imp | `imp` | Runs off-road to a random spot and gnaws the paper (visible progress ring, ~4 s). If it finishes, the map **tears** there (same holes as wear & tear). Killing it cancels. From wave 5. |
Each first appearance emits `Events.enemy_introduced(kind)` (Helper #21 shows the card).
Sprites: `assets/sprites/units/enemy_pinner.png`, `enemy_flyer.png`, `enemy_imp.png` (placeholder draw until they land).
As built: the pin zone is drawn by `FoldController` (red edge bands + arc); `FoldController.pin_at(g)`
refuses grabs, `Unit.refuse()` shakes the nail. A flipped Pin-Bearer loses his nail and walks back to
re-hammer it; a flipped imp restarts gnawing. The imp prefers spots next to your buildings (70%), tears
via `FoldController.tear_at(p)`, then dives into its hole (`Unit.escaped`, no ink). Flyers ignore holes
and knights. SFX names: `pin`, `pin_block`. Test: `scenes/tests/enemies_test.tscn`.

### 12-wave run (done, task #22c)
12 waves (~15 min). Mid-boss at **wave 6** (Iron Warlord, triggers a Duel), final boss at **wave 12**
(Siege Ram + its driver, Duel first). Decree after every wave. New enemies ramp in (runner 3,
brute 4, pinner 3, flyer 4, imp 5...). As built: `Waves.LIST`, bosses + their banners in `Waves.BOSSES`
(the boss enters 5th in its wave's queue). Test: `scenes/tests/run_test.tscn` fast-forwards a whole run.

### Duel of Champions (done, task #23) — first-person boss duel
When a boss arrives the map freezes and a full-screen **first-person** duel starts (portrait):
the boss towers in the center facing you; the Champion's gauntlet+sword (right) and shield (left)
sit at the bottom of the screen. Painted-page look, background `duel_bg.png`.
- **Rounds (turn-based rhythm):** the boss **winds up** a clearly telegraphed attack: swing from
  LEFT, swing from RIGHT, or OVERHEAD smash (plus fake-outs for the final boss). The player
  answers with a **swipe**: dodge right / dodge left / swipe up = raise shield. Correct read →
  a short **strike window**: tap repeatedly to hit (each tap = damage + hit flash + shake).
  Wrong/no read → the Champion takes a hit (3–4 hits = knocked out).
- **Stagger bar:** fills with hits. Full → "FOLD IT!": the page's edge glows; drag it over the
  boss and release = the page folds onto the boss (fold finisher, big slam, ink splash).
- **Outcome:** win → mid-boss defeated outright (big ink reward) / final boss enters the map
  wounded (1 crush left). Lose → boss enters at full strength and the Keep takes 2 damage.
- Animation in code (tweens: lunges, squash, shake, flashes, telegraph arrows/glow). Placeholder
  shapes until art lands: `duel_<boss>_idle/windup/hurt.png` (boss = `warlord`, `driver`),
  `duel_champion_arm.png`, `duel_champion_shield.png`, `duel_bg.png` in `assets/sprites/duel/`.
- Single pointer only (swipe = drag with direction; tap = press/release short). Must work while
  the map is frozen (the duel scene can pause the tree and use `process_mode ALWAYS`).
- Suggested files: `scenes/duel/duel.tscn`, `scripts/duel/duel.gd` (Claude-owned). Trigger from
  `main.gd` when a boss spawns; `Events.duel_started(boss)` / `Events.duel_finished(won)`.
- **As built:** `main.gd` `_duel(kind)` runs when a boss is popped from the spawn queue (waits for
  any fold in hand to finish), pauses the tree and awaits `Duel.finished`. Tuning in `Duel.BOSSES`
  (stagger 100/120, tell time, fake-out chance 0/40% from round 3) and the constants at the top of
  `duel.gd` (3 Champion hearts, 1.6 s strike window, 5 per tap, 8 for a correct read). The first 2
  rounds show the answer arrow. Warlord win = +12 ink (`main.DUEL_REWARD`); loss = Keep −2 (never
  below 1). `Duel.resolve(won)` ends a duel instantly (tests). SFX names: `duel_windup`, `duel_swing`,
  `duel_clang`, `duel_whoosh`, `duel_dodge`, `duel_hit`, `duel_hurt`, `duel_stagger`.
  Test: `scenes/tests/duel_test.tscn` (real mouse swipes/taps/fold, one win and one loss).

## Tech
- **Godot 4.7.2**, **GL Compatibility** renderer (required for web), web export **without threads**
  (no SharedArrayBuffer needed on itch).
- **Resolution:** base viewport **360×640**, stretch mode `canvas_items`, aspect `keep`, default
  texture filter **Linear** (painted art, see ART_BRIEF.md). The map SubViewport renders at
  `main.gd` `RENDER_SCALE` (2×, i.e. 720×1280) with World scaled up, so gameplay code still works in
  base (360×640) coordinates. Everything below is in base pixels.
- **Input:** handle **mouse events only**. `emulate_mouse_from_touch` is on, so touch works too.
  Optional two-finger extras go in the `InputEventScreenTouch` handlers.

### Scene architecture
```
Main (Node2D)                      scenes/main.tscn, scripts/main.gd
├─ MapViewport (SubViewport 360×640)   ← everything "printed on the paper" lives here
│  └─ World (Node2D)
│     ├─ Paper      (parchment, roads, terrain decals)
│     ├─ Buildings  (group "building")
│     └─ Units      (groups "unit" + "enemy"/"ally")
├─ MapDisplay (Sprite2D)          ← shows MapViewport texture through shaders/fold.gdshader
├─ FoldController (Node)          ← scripts/fold/fold_controller.gd: input, fold math, slam
├─ Fx (Node2D, added at runtime)  ← scripts/fx/fx.gd: dust, droplets, rings, popups above the folded map
└─ UI (CanvasLayer)               ← HUD, build menu, screens
```
- **Coordinates:** map space (World-local) = base-viewport pixels (the map sits at the origin).
- **Fold math** (`scripts/fold/fold_math.gd`): line point `M = (G+P)/2`, normal `n = normalize(G-P)`,
  flap = `dot(x-M, n) > 0`, `mirror(x) = x - 2·dot(x-M, n)·n`.

### Contracts between systems
- **Units** (`scripts/units/unit.gd`): `func on_crushed()`, `func on_slapped(dir: Vector2)`,
  `func on_flipped(to: Vector2)`. Signal `died(unit)`.
- **Buildings** (`scripts/buildings/building.gd`): `@export var heavy: bool`,
  `func contains_point(p: Vector2) -> bool`.
- **FoldController** signals: `fold_started`, `slammed(line_point: Vector2, normal: Vector2)`,
  `unfolded`.
- **Fx** (`scripts/fx/fx.gd`): `Fx.of(node)` returns the layer; `dust()`, `dust_ring()`, `droplets()`,
  `ring()`, `star()`, `text()`. Any system may call these for juice.
- Game-wide events go through the autoload `Events` (signal bus). Audio goes through the `Audio`
  autoload (`Audio.play_sfx("slam")`, `Audio.play_music("battle")`).

## Folder layout & ownership
| Path | Owner | Others |
|---|---|---|
| `scripts/fold/`, `shaders/fold.gdshader` | **Claude** | Don't edit. Ask in TASKS.md. |
| `scripts/fx/`, `scripts/tests/`, `scenes/tests/` | Claude | Call the Fx API freely; ask before editing |
| `scripts/main.gd`, `scripts/units/`, `scripts/buildings/` | Claude (v0.1), then open | Coordinate via TASKS.md |
| `scenes/ui/`, `scripts/ui/`, `scripts/autoload/audio.gd` | **Helper agent** (Antigravity, after prototype lock) | |
| `assets/` | **Human** (ChatGPT images / Suno / fish.audio) | Agents only read |

## Asset conventions
- `assets/sprites/{units,buildings,terrain,fx,ui}/`, `assets/audio/{music,sfx,voice}/`
- snake_case names. Sprite sheets are **horizontal strips** named `name_WxH_Nf.png`,
  e.g. `enemy_grunt_walk_32x32_4f.png`.
- See `ART_BRIEF.md` for sizes, palette and prompts.
