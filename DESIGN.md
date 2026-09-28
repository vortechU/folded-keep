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
5. **Creases:** each slam leaves a visible crease line. *Wear & tear rule TBD after the prototype.
   Leading candidate: slamming across 3+ existing creases tears the map and leaves a permanent
   chasm. Things printed on the chasm are lost; units walking into it fall.*
6. **Enemies** (red ink) walk the roads from the top edge toward the **Keep** (bottom center).
   Reaching the Keep damages it. Keep HP 0 = defeat.
7. **Build phase** between waves: spend **Ink** (earned from kills) to stamp buildings on
   non-road paper.
8. **Waves:** 6 waves, then a 7th boss wave. Survive all of them = victory. Endless mode is a stretch goal.

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
| Boss: Siege Ram | Wave 7 (final). Needs 3 crushes, ignores slaps, breaks walls in one hit, deals 5 Keep damage. Flipping it throws it back up the road. |

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
