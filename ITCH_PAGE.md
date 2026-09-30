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
  **barracks** (knights that hold enemies in place), and **Archer Towers** (two arrows shoot down a Crow Rider).
  Regular towers attack through folds; each tower crush drops a temporary guard.
- **Mind the paper.** Every slam leaves a crease. Where three creases meet, the map **rips open**.
  Enemies fall through the hole... and so do your buildings.
- **Keep Slam:** fold the bottom edge up and slam your own castle onto the enemy. It hurts the
  Keep a little, but nothing hits harder.
- Survive **8 waves**. Face the **Iron Warlord** at wave 6 and the **Siege Ram** at wave 8.
- Before each boss, fight a **Duel of Champions**: swipe away from side attacks, swipe up to
  block overhead attacks, then tap to strike. Fill the stagger bar and fold the page for the finisher.
- Choose a permanent **Royal Decree** between waves. Open the **Field guide** from the menu
  or pause screen for fold rules and enemy counters.

### Controls
One finger (or one mouse button). Drag from any edge to fold. Tap the stamps to build.
Tap **LOOK** during a wave for a closer view; drag to pan and tap **BACK** to return.
Works on phones (portrait) and desktop.

### Features
- A physical paper-folding mechanic: aim with a live preview of who gets crushed, slapped
  or flipped
- The map remembers every battle: ink splats, creases and stitched-up tears stay for the whole run
- 8 enemy types including two bosses, 4 buildable defenses, and allied knights
- Pin-Bearers nail the map, Crow Riders fly over crushing folds, and Ink Imps chew holes in the paper
- Royal Decrees, first-person boss duels, rain, fog, and storms that blow Crow Riders off course
- A guided first tower crush, illustrated Field Guide, and a Royal Battle Report with an earned commendation
- Hand-illustrated war-map art style

### Made with AI (SlapJam AI #1)
Built in 48 hours for SlapJam AI #1 (theme: **Castles**), with AI tools for every part:
- **Design & code:** Claude Code (Claude Opus 5.5) and Codex (ChatGPT), in Godot 4.7
- **Art:** ChatGPT image generation
- **Music:** Suno
- **Sound effects:** imported audio-library sounds; rain recordings by Fesliyan Studios, thunder by CDanSantana, synthesized wind gusts

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

The current upload was exported from an isolated source copy with editor-only MCP tooling
excluded. The add-on's export hook reports a Windows safe-save error in the main checkout;
`builds/final_additions/rebuild_web.ps1` repeats the clean export and rebuilds the ZIP without
changing the source project's settings.

```bash
"C:/Apps/Godot_v4.7.2-stable_win64.exe/Godot.exe" --headless --path . --export-release "Web" builds/web/index.html
"C:/Apps/Godot_v4.7.2-stable_win64.exe/Godot.exe" --path . --resolution 576x1024 res://scenes/tests/capture.tscn -- --autotest-capture=C:/Dev/Gamedev/AIgamejam/builds/capture
python tools/itch_media.py builds/capture builds/itch
```
Then rebuild the zip (PowerShell):
```powershell
Compress-Archive -Path (Get-ChildItem builds/web -Exclude *.import) -DestinationPath builds/FoldedKeep_web.zip -Force
```
