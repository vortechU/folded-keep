class_name Decrees
## Royal Decrees: after each cleared wave the King offers 3, you pick 1. They last the whole run.
## Data lives here (UI reads LIST for names and text). Gameplay checks `Decrees.has(id)`.
## Owner: Claude (effects). UI: Helper (card screen, see TASKS.md).

## id -> {name, text, icon}. `icon` is a short keyword the UI may map to an icon/sprite.
const LIST := {
	"heavy_stock": {"name": "Heavy Stock", "text": "Walls are heavy too: they crush like towers.", "icon": "wall"},
	"wet_ink": {"name": "Wet Ink", "text": "Every crush splashes: enemies close by get slapped.", "icon": "splat"},
	"paper_cut": {"name": "Paper Cut", "text": "The flap's edge slices: enemies right under it are crushed.", "icon": "blade"},
	"royal_treasury": {"name": "Royal Treasury", "text": "+1 Ink for every enemy defeated.", "icon": "ink"},
	"stone_keep": {"name": "Stone Keep", "text": "The Keep gains +4 max HP and is fully repaired.", "icon": "keep"},
	"reinforcements": {"name": "Reinforcements", "text": "Barracks field 3 knights instead of 2.", "icon": "knight"},
	"deep_rips": {"name": "Deep Rips", "text": "Tears swallow 6 enemies before they're stitched shut.", "icon": "tear"},
	"thick_parchment": {"name": "Thick Parchment", "text": "Keep Slams no longer cost the Keep any HP.", "icon": "keep"},
	"masons_guild": {"name": "Mason's Guild", "text": "Walls cost 1 less Ink and have double HP.", "icon": "wall"},
	"aftershock": {"name": "Aftershock", "text": "Slams stun every enemy near the crease.", "icon": "crease"},
	"flip_tax": {"name": "Flip Tax", "text": "Flipped enemies land hard: they're slapped on arrival.", "icon": "flip"},
	"slow_time": {"name": "Steady Hand", "text": "Time slows even more while you aim a fold.", "icon": "hourglass"},
}

## Decrees chosen this run. Reset by main.gd when a run starts.
static var active: Array[String] = []


static func has(id: String) -> bool:
	return active.has(id)


static func reset() -> void:
	active.clear()


## `count` random decrees the player doesn't have yet.
static func roll(count: int) -> Array[String]:
	var pool: Array[String] = []
	for id: String in LIST:
		if not active.has(id):
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, count)
