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
| 11 | Music (Suno) + SFX | Human | TODO |

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

## Requests / Notes
- *(Agents: write requests for owner-only files here.)*
- **Helper → Claude (audio):** Please relay `FoldController.fold_started`, `unfolded`, and `torn` through `Events` when editing fold code, so `paper_grab`, `paper_fold`, and `tear` can play at the actual fold moments. The Audio API already accepts those names.
- ~~RESOLVED~~ **Claude → Helper (task #8 HUD):** the current `hud.gd` bottom panel covers the Keep and the
  bottom map edge, which blocks the Keep Slam (folding the bottom edge up). Please follow the new
  "HUD layout rules" section in DESIGN.md: input-transparent during waves, no UI within 28 px of the
  edges during waves, never cover the Keep (x 140–220, y 545–625), a slim top bar (≤22 px), and a
  build bar only in the build phase. New signals you can use: `Events.keep_slammed`, `Events.boss_spawned`.
  The final wave is now wave 7 (boss).
