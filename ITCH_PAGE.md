# Folded Keep — itch.io page kit

Media lives in `builds/itch/` (regenerate any time, see "Refreshing the media" at the bottom).
The upload zip is `builds/FoldedKeep_web.zip`.

---

## Page text (paste into the itch "Description" box)

**Title:** Folded Keep
**Short description / tagline:** Fold the map. Crush the siege.

> *The only thing standing between the invaders and your castle is the map on your war table.
> So fold it.*

**Folded Keep** is a castle-defense game where your weapon is the parchment map itself. Grab any
edge, drag it inward, and let go: the paper **slams down**, and whatever is inked on the flap lands
on whatever is below. Towers crush soldiers. Soldiers on the flap get flipped to the other side.
Everything else gets slapped.

### How to play
- **Drag any edge of the map inward, then release** to slam it down. Red X = crushed,
  gold ring = slapped, blue line = flipped.
- **Between waves**, spend Ink to stamp **towers** (heavy, they crush), **walls** (block the road)
  and **barracks** (knights that hold enemies in place, which makes them perfect targets).
- **Mind the paper.** Every slam leaves a crease. Where three creases meet, the map **rips open**.
  Enemies fall through the hole... and so do your buildings.
- **Keep Slam:** fold the bottom edge up and slam your own castle onto the enemy. It hurts the
  Keep a little, but nothing hits harder.
- Survive 7 waves, including the **Siege Ram**.

### Controls
One finger (or one mouse button). Drag from any edge to fold. Tap the wax seals to build.
Works on phones (portrait) and desktop.

### Features
- A physical paper-folding mechanic: aim with a live preview of who gets crushed, slapped
  or flipped
- The map remembers every battle: ink splats, creases and stitched-up tears stay for the whole run
- 5 enemy types including the Siege Ram boss, 3 buildings, allied knights
- Hand-illustrated war-map art style

### Made with AI (SlapJam AI #1)
Built in 48 hours for SlapJam AI #1 (theme: **Castles**), with AI tools for every part:
- **Design & code:** Claude Code (Claude Opus 5.5) and Codex (ChatGPT), in Godot 4.7
- **Art:** ChatGPT image generation
- **Music:** Suno *(fill in when added)*
- **Sound effects:** *(fill in: ElevenLabs / sfxr)*
- **Voice:** fish.audio *(only if used)*

Made by *(your name / team)*.

---

## Upload checklist (itch.io → Dashboard → Create new project)
1. **Kind of project:** HTML.
2. **Uploads:** upload `builds/FoldedKeep_web.zip`, tick **"This file will be played in the
   browser"**.
3. **Embed options:**
   - Viewport dimensions: **450 × 800**
   - Tick **Mobile friendly**, orientation **Portrait**
   - Tick **Fullscreen button**
   - Leave **SharedArrayBuffer support** OFF (the build doesn't use threads)
4. **Details:** Genre **Strategy**. Tags: `castle`, `tower-defense`, `paper`, `mobile`,
   `one-button`, `godot`, `ai-generated`.
5. **Media:** Cover image `builds/itch/cover.png` (630×500). Screenshots:
   `builds/itch/fold.gif` first (it's the best pitch), then `screenshot_1..5.png`.
6. **Pricing:** No payments.
7. **Theme** (Edit theme on the page): background `#2A1D14`, text `#EAD9B0`,
   links/buttons `#D9A43A`. Font: a serif (Georgia-like) fits the map look.
8. **Visibility:** save as **Draft** first. Open the page on your **phone** and on desktop, play
   one wave on each, then set it to **Public**.
9. **Submit to the jam:** on the jam page, click **Submit your project** and pick Folded Keep.
   Do this well before the deadline; itch jams close exactly on time.

---

## Refreshing the media
After art or audio changes, re-export and re-capture:

```bash
"C:/Apps/Godot_v4.7.2-stable_win64.exe/Godot.exe" --headless --path . --export-release "Web" builds/web/index.html
"C:/Apps/Godot_v4.7.2-stable_win64.exe/Godot.exe" --path . --resolution 576x1024 res://scenes/tests/capture.tscn -- --autotest-capture=C:/Dev/Gamedev/AIgamejam/builds/capture
python tools/itch_media.py builds/capture builds/itch
```
Then rebuild the zip (PowerShell):
```powershell
Compress-Archive -Path (Get-ChildItem builds/web -Exclude *.import) -DestinationPath builds/FoldedKeep_web.zip -Force
```
