# Folded Keep — Art & Audio Brief (for the human + generation tools)

**Style: painted "illustrated map" (not pixel art).** The map renders at 720×1280 with smooth
filtering, so painted art stays sharp. You don't need exact pixel sizes: generate big and I scale
each sprite in code. Drop finished files into the folders listed.

**Every sprite:** transparent PNG, square canvas, subject centered and filling ~85% of it, nothing
cropped at the edges, no text, no ground or shadow (I draw shadows in code).

## Art direction: "Inked war map"
An old medieval campaign map, like the illustrations in a fantasy book: hand-inked outlines with
flat watercolor washes. Buildings in 3/4 view like old cartography drawings, soldiers like little
painted **game pieces** on the map. **Color = team:**
- **Blue = you** (buildings, knights)
- **Red = invaders**
- Sepia/brown = neutral terrain (trees, hills, rocks)

### Palette (stick to it, it's what makes everything feel like one game)
| Role | Hex |
|---|---|
| Parchment light / mid / shadow | `#EAD9B0` `#D8C08A` `#B89A62` |
| Dark ink (outlines) / sepia | `#3A2A1C` `#6E4B2A` |
| Player blue / light blue | `#2F4F8F` `#5B7FC0` |
| Enemy red / light red | `#A8322D` `#D0584A` |
| Gold accent (Ink currency, highlights) | `#D9A43A` |
| Table under the map (dark wood) | `#2A1D14` |

### Tool: ChatGPT image generation (Plus)
Paste this **style prompt** at the start of every request, word for word:
> Hand-inked fantasy map illustration, bold dark brown ink outlines, flat watercolor washes,
> muted limited palette of parchment, sepia, faded blue and faded red with small gold accents,
> 3/4 top-down view like an old cartography drawing, single isolated object, centered,
> transparent background, no text, no ground, no shadow.

**Consistency trick:** make the **Keep** first. When you love it, do everything else **in the same
chat** and say *"same style as the keep image above"*, or attach the keep as a reference in a new
chat. Keep outlines, line weight and colors identical across assets. If an image comes back with a
background instead of transparency, ask again with "transparent background PNG".

## Step 1: Style lock (do first). Send me the files when done.
| File | Prompt (after the style prompt) |
|---|---|
| `buildings/keep.png` | a small stone castle keep with four round corner towers, faded blue roofs, a blue banner |
| `units/enemy_grunt.png` | a small red-painted foot-soldier game piece with a spear, facing the viewer |
| `buildings/tower.png` | a round stone watchtower with a faded blue conical roof |

## Step 2: Everything else
**Buildings** → `assets/sprites/buildings/`
| File | Prompt |
|---|---|
| `wall.png` | a short straight crenellated stone wall segment seen from above at an angle, horizontal |
| `barracks.png` | a long wooden hall with a faded blue roof, a blue flag and crossed swords over the door |

**Units** → `assets/sprites/units/` (one image each; I animate them in code: bob, squash, flips)
| File | Prompt |
|---|---|
| `enemy_runner.png` | a skinny red-painted scout game piece with a dagger, leaning forward, running |
| `enemy_brute.png` | a huge red-painted armored ogre game piece with a club |
| `boss_siege_ram.png` | a red-painted wooden battering ram on wheels with a sloped roof, iron ram head |
| `ally_knight.png` | a blue-painted knight game piece with a sword and a round shield |

**Terrain** → `assets/sprites/terrain/` (sepia ink, small decals)
- `tree_1..3.png`, `pine_1..2.png`, `hill_1..2.png`, `rock_1..2.png`, `bush.png`, `hut.png`
- `paper.png` (optional, **portrait 1024×1536**, not transparent): *aged parchment paper
  texture, top-down, flat even lighting, subtle stains and fibers, no ink, no drawings, no border*
- *Roads, rivers, creases, ink splats and dust are drawn in code. No art needed for them.*

**UI** → `assets/sprites/ui/` (optional)
- Icons: tower, wall, barracks, ink drop (currency), heart (Keep HP), pause. Same style prompt.
- **Font** → `assets/fonts/`: download from Google Fonts: **IM Fell English SC** (titles) and
  **IM Fell English** (text), or **Cinzel** if you prefer something cleaner.

## Animations
None needed. Units are single images animated in code (walk bob, squash on hits, flips, stamps).

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
