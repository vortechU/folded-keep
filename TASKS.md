# Folded Keep — Task Board

Status: `TODO` · `IN PROGRESS` · `DONE` · `BLOCKED`. Owners: **Claude**, **Human**, **Helper** (Antigravity preferred, Cline or OpenCode for small tasks).

## Milestones (hours from jam start)
| When | Milestone |
|---|---|
| H+6 | Fold prototype feels good → **concept locked** |
| H+16 | Core loop playable: waves, build phase, crush/slap/flip, Keep HP, win/lose |
| H+28 | Content complete: all enemies, buildings, 6 waves + boss, real art and audio in |
| H+38 | Polish & juice done (shake, particles, squash, audio mix, tutorial) |
| H+42 | Web build uploaded to itch as a **draft**, tested on a real phone + desktop |
| H+46 | **Submit.** Final 2h are buffer only, no new features. |

## Phase 1: Prototype (now)
| # | Task | Owner | Status |
|---|---|---|---|
| 1 | Project setup: Compatibility renderer, 360×640 portrait, pixel filtering, web export preset (no threads) | Claude | DONE: web export verified in a browser (WebGL2, mouse folding works) |
| 2 | Fold prototype: parchment, edge drag, fold shader, slam, crush/slap/flip dummy enemies | Claude | DONE: placeholder art is drawn in code; press R to restart |
| 3 | Style lock: keep + grunt + parchment tile (ART_BRIEF.md step 1) | Human | TODO |
| 4 | Playtest prototype, go/no-go on concept | Human + Claude | DONE: concept **locked** |

## Phase 2: Core loop (after lock)
| # | Task | Owner | Status |
|---|---|---|---|
| 5 | Roads + enemy pathing, wave spawner, Keep HP | Claude | DONE: 6 waves in `scripts/game/waves.gd`, win/lose |
| 6 | Build phase: Ink currency, stamping buildings, placement rules | Claude | DONE: towers on open paper, walls snap across roads (6 HP) |
| 7 | `Audio` autoload (music crossfade, sfx pool), hooked to `Events` signals. `Events` already exists | Helper | DONE: registered web-safe Audio with crossfading music, pooled SFX, Events cues, and silent loading of missing ART_BRIEF files; fold grab/tear cues await bus signals from Claude. |
| 8 | Real HUD replacing `scripts/ui/proto_hud.gd` (same Events API): Keep HP, Ink, wave, build buttons, wax-seal style | Helper | DONE: replaced prototype with wax-seal HUD; Keep/Ink/wave and build controls use Events only. Costs are 4/3 in UI. |
| 9 | Main menu, pause, victory/defeat screens | Helper | DONE: added parchment menu, pause, and result screens; one-pointer buttons use Events for restart and leave wave edges clear. Reviewer follow-up: restart now skips the menu and drops straight into a fresh, unpaused wave 1 (`scripts/ui/game_screens.gd`); banner hide time tightened to ~1.45s (`scripts/ui/hud.gd`). |
| 10 | All remaining sprites + walk animations (ART_BRIEF step 2) | Human | TODO |
| 11 | Music (Suno) + SFX | Human | IN PROGRESS: music DONE, trimmed loops in `assets/audio/music/` (menu = build phase + menu, battle, boss, victory, defeat; loop is set by `audio.gd`); SFX still TODO |

## Phase 3: Content & polish
| # | Task | Owner | Status |
|---|---|---|---|
| 12 | Enemy types (runner, brute) + boss | Claude | DONE: runner, brute, Siege Ram boss (wave 7) + Keep Slam |
| 13 | Wave tuning (6 waves + boss) | Helper | DONE: waves 1–6 now rise by two enemies each with gentler spawn timing; wave 7 has a lean escort for the Siege Ram. Starting 8 ink still buys barracks + wall; headless smoke test clean. |
| 14 | Juice: screen shake, dust, splats, squash & stretch, hit-stop | Claude | DONE: `scripts/fx/fx.gd` layer (slam dust from flap edges, flap flash, ink droplets, combo + reward popups, stamp-in buildings, slap stars). Test: `scenes/tests/juice_test.tscn` |
| 15 | 20-second tutorial (first wave teaches the fold with a hand icon) | Helper | DONE: `scripts/ui/fold_tutorial.gd` (added by hud.gd): wave 1 only, small parchment note on empty paper at bottom-left + animated hand dragging the right edge inward; input-transparent, hides while the pointer is held, clears on first slam or after 20 s, and a static flag keeps it from returning after restart. Smoke + juice/knights/tear/autotest clean. |
| 19 | Barracks + blue knights | Claude | DONE: 5 ink, squad of 2 guards the nearest road, pins enemies in melee (enemy `hp`/`hit` in `unit.gd` KINDS); folds hurt knights too. Test: `scenes/tests/knights_test.tscn` |
| 16 | Wear & tear crease rule (decide after playtest) | Claude | DONE: 3 creases meeting rip a hole (preview marker), holes swallow 3 units then get patched; buildings on a rip are lost. Test: `scenes/tests/tear_test.tscn` |
| 17 | King voice lines (optional) | Human | TODO |
| 18 | Web export, itch page, cover art, GIFs, phone test | Claude + Human | TODO |

## Phase 4: Depth (to win)
| # | Task | Owner | Status |
|---|---|---|---|
| 20 | **Royal Decree card screen.** On `Events.decree_offered(ids)` show 3 parchment cards (name + text from `Decrees.LIST[id]`, optional icon by `icon` keyword), the King's seal on top ("THE KING DECREES"). Tap a card → `Events.decree_chosen.emit(id)` and close. Game is not paused but nothing moves (phase is OVER meanwhile), so the screen must use `process_mode ALWAYS`-safe code and block input only while shown. Also show the run's active decrees as small seals somewhere unobtrusive during the build phase (tap/hover shows the text). Portrait, respect HUD layout rules. | Helper | DONE: added royal choice cards and build-phase decree seals with tap/hover details in `scripts/ui/royal_decrees.gd`; choice emits through Events. |
| 21 | **New enemy intro card.** On `Events.enemy_introduced(kind)` show a short card for ~3 s (or until tapped) with the enemy name + one-line tip. Texts: `pinner` "PIN-BEARER — Nails a corner of the map. You can't fold near him until he's gone.", `flyer` "CROW RIDER — Flies over walls. Can't be crushed: flip it, or fling it off the map!", `imp` "INK IMP — Gnaws the paper. If it finishes, the map tears.". Must not block folding (mouse_filter IGNORE, tap-to-dismiss via `_input` without consuming). | Helper | DONE: added queued three-second, tap-dismissable enemy notes in `scripts/ui/enemy_intro.gd`; pointer events still reach folding. |
| 22a | Decree effects + fling-off-map rule | Claude | DONE: all 12 decrees work (test `scenes/tests/decree_test.tscn`); fling = gold arrow preview |
| 22b | Fold-aware enemies: pinner, flyer, imp (spec in DESIGN.md) + `enemy_introduced` | Claude | DONE: behaviors in `unit.gd`, pin blocking + `tear_at` in `fold_controller.gd`; units right under the pointer are now always hit (2 px slack). Test: `scenes/tests/enemies_test.tscn` |
| 22c | 12-wave run with mid-boss at wave 6 (spec in DESIGN.md), retune waves.gd | Claude | DONE: 12 waves in `waves.gd`, Iron Warlord (`warlord`, 2 crushes) leads wave 6, Siege Ram wave 12. Test: `scenes/tests/run_test.tscn` (full run, decree picks, both bosses) |
| 23 | Duel of Champions: first-person boss duel (spec in DESIGN.md) | Claude | DONE: `scenes/duel/duel.tscn` + `scripts/duel/duel.gd`, triggered by `main.gd` `_duel()` for both bosses; placeholder art in code, loads `assets/sprites/duel/*.png` when present. Test: `scenes/tests/duel_test.tscn` |
| 24 | Ink look: line boil + ink reveal on units/buildings | Claude | DONE: `shaders/ink.gdshader` (one material per unit/building, `reveal` 0..1, 4 fps boil). Units ink in as they step onto the map (+ quill scribble fx), crushed units soak away, stamps soak in, splats bleed outward. Test: `scenes/tests/ink_test.tscn` |
| 25 | Living map: wind curls, aged paper, cloud shadows | Claude | DONE: `scripts/world/wind.gd` (quill wind strokes along a flow field, added by `main._add_atmosphere`), `shaders/paper.gdshader` (baked once into a texture by `paper.gd`), `shaders/clouds.gdshader` (overlay above units). All inside the map, so they fold with it. |
| 26 | Old-map decoration | Claude | DONE: `scripts/world/decor.gd` (river + lake with a sea serpent, hatched hills, forests, title banner, compass rose, scale bar) baked once into the paper texture; bridges drawn over the roads in `paper.gd`. Can't build on water (`Paper.on_water`). |

## Requests / Notes
- *(Agents: write requests for owner-only files here.)*
- **Claude → Human (art/audio):** new placeholder-drawn content is waiting for files: units `enemy_pinner.png`,
  `enemy_flyer.png`, `enemy_imp.png`, `boss_warlord.png`; duel art in `assets/sprites/duel/` (see DESIGN.md);
  SFX `pin`, `pin_block`, `duel_windup`, `duel_swing`, `duel_clang`, `duel_whoosh`, `duel_dodge`, `duel_hit`,
  `duel_hurt`, `duel_stagger`. Everything loads by name and skips missing files.
- **Helper → Claude (audio):** Please relay `FoldController.fold_started`, `unfolded`, and `torn` through `Events` when editing fold code, so `paper_grab`, `paper_fold`, and `tear` can play at the actual fold moments. The Audio API already accepts those names.
- ~~RESOLVED~~ **Claude → Helper (task #8 HUD):** the current `hud.gd` bottom panel covers the Keep and the
  bottom map edge, which blocks the Keep Slam (folding the bottom edge up). Please follow the new
  "HUD layout rules" section in DESIGN.md: input-transparent during waves, no UI within 28 px of the
  edges during waves, never cover the Keep (x 140–220, y 545–625), a slim top bar (≤22 px), and a
  build bar only in the build phase. New signals you can use: `Events.keep_slammed`, `Events.boss_spawned`.
  The final wave is now wave 7 (boss).
