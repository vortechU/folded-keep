# Folded Keep — Art & Audio Brief (for the human + generation tools)

Game resolution is **360×640** (pixel art, scaled up 2× or 3× on screen). All sizes below are in
those pixels. Drop finished files into the folders listed. Use **transparent PNG** for sprites.

## Art direction: "Inked war map"
An old medieval campaign map on parchment. Everything is drawn in ink: buildings in 3/4 view
like old cartography illustrations, and little soldiers like map tokens. **Color = team:**
- **Blue ink = you** (buildings, knights)
- **Red ink = invaders**
- Sepia/brown ink = neutral terrain (trees, hills, roads, rivers)

### Palette (stick to it, it's what makes everything feel like one game)
| Role | Hex |
|---|---|
| Parchment light / mid / shadow | `#EAD9B0` `#D8C08A` `#B89A62` |
| Dark ink (outlines) / sepia | `#3A2A1C` `#6E4B2A` |
| Player blue / light blue | `#2F4F8F` `#5B7FC0` |
| Enemy red / light red | `#A8322D` `#D0584A` |
| Gold accent (Ink currency, highlights) | `#D9A43A` |
| Table under the map (dark wood) | `#2A1D14` |

### Style prompt (paste at the start of every PixelLab prompt)
> pixel art, medieval campaign map illustration, hand-inked on parchment, clean 1px dark brown
> outline, limited palette, 3/4 top-down view, transparent background

**Consistency trick:** make the **Keep** first. When you love it, use it as the **style reference /
init image** for everything else in PixelLab.

## Step 1: Style lock (do first, ~1–2h). Send me screenshots when done.
| File | Size | Prompt idea (after the style prompt) |
|---|---|---|
| `buildings/keep.png` | 96×96 | blue-ink stone castle keep with 4 towers and a blue banner |
| `units/enemy_grunt.png` | 32×32 | small red-ink foot soldier with spear, facing down/south, chunky readable silhouette |
| `terrain/parchment_tile.png` | 128×128 | seamless tileable aged parchment paper texture, subtle stains, no ink |

## Step 2: Everything else
**Buildings** → `assets/sprites/buildings/` (blue ink)
| File | Size | Notes |
|---|---|---|
| `tower.png` | 48×48 | round stone watchtower, blue roof |
| `wall.png` | 48×48 | short horizontal crenellated wall segment, centered |
| `barracks.png` | 48×48 | wooden hall with blue flag and crossed swords |

**Units** → `assets/sprites/units/` (every unit also needs a walk animation, see AutoSprite below)
| File | Size | Notes |
|---|---|---|
| `enemy_grunt.png` | 32×32 | (from step 1) |
| `enemy_runner.png` | 32×32 | skinny red-ink scout with a dagger, leaning forward |
| `enemy_brute.png` | 48×48 | huge red-ink armored ogre/knight with a club |
| `boss_siege_ram.png` | 96×96 | red-ink wooden battering ram on wheels with a roof, facing down |
| `ally_knight.png` | 32×32 | blue-ink knight with sword and shield, facing **up/north** |

**Terrain decals** → `assets/sprites/terrain/` (sepia ink, 16×16 or 32×32, transparent)
- tree ×3 variants, pine ×2, hill ×2, rock ×2, bush, small village hut, bridge (32×32), river piece
- *Roads are drawn in code (dashed ink lines). You don't need road art.*

**FX** → `assets/sprites/fx/`
| File | Size | Notes |
|---|---|---|
| `ink_splat_1..3.png` | 32×32 | red ink splatter (what's left of a crushed enemy) |
| `dust_puff_16x16_4f.png` | 16×16 ×4 frames | parchment-colored dust puff (slam impact) |
| `stamp_ring.png` | 48×48 | wax-seal style ring (build placement marker) |

**UI** → `assets/sprites/ui/`
- Icons 24×24: tower, wall, barracks, ink drop (currency), heart (Keep HP), pause.
- `wax_seal_button.png` 64×64: red wax seal (a round button).
- **Font:** any free pixel font. I suggest **m5x7** or **Pixel Operator** (download it, drop the `.ttf` in `assets/fonts/`).

## AutoSprite: animations
For each unit PNG: upload it → generate a **walk cycle, 4 frames** (enemies face **down**, the
knight faces **up**). Export as a **horizontal strip PNG**, e.g. `enemy_grunt_walk_32x32_4f.png`.
Death and squash animations are **not** needed, since I squash sprites in code.

## Suno: music → `assets/audio/music/` (instrumental, mp3 or ogg)
1. **`menu.mp3`**: *medieval folk, lute and recorder, warm and whimsical, map-room adventure, instrumental, loopable, 90 bpm*
2. **`battle.mp3`**: *upbeat medieval battle folk, driving frame drums, fiddle and lute, playful tension, instrumental, loopable, 120 bpm*
3. **`boss.mp3`**: *epic medieval siege, war drums, low brass, choir ahh, intense, instrumental, loopable, 135 bpm*
4. **`victory.mp3` / `defeat.mp3`**: short fanfare / sad lute. Cut the first 5–8 s of a generation.

## Sound effects → `assets/audio/sfx/`
Use ElevenLabs Sound Effects (free tier) or sfxr.me (free, no account). Short (<1 s), ogg/wav:
`paper_grab` (rustle), `paper_fold` (whoosh), `slam` (heavy paper THWACK), `crush` (crunch),
`splat` (wet ink), `stamp` (wax seal thunk), `ink_gain` (coin clink), `keep_hit` (stone crack),
`wave_horn` (war horn), `tear` (paper rip), `ui_click`.

## fish.audio: voice (OPTIONAL, lowest priority) → `assets/audio/voice/`
One character: **the King**, a pompous, slightly panicky old monarch narrating from off-screen.
Lines: "Fold them!" · "Mind the map, it's the only copy!" · "Here they come!" ·
"Crushed like parchment!" · "Not the keep!" · "Victory! Frame this map!" · "We are... undone."
Name the files by line, e.g. `king_fold_them.mp3`.

## Itch page (last day)
Cover image 630×500 and 3–5 screenshots/GIFs. I'll set up the capture once the game is playable.
