class_name Waves
## An 8-wave demo: new enemy kinds ramp in over waves 3-5, the Iron Warlord leads
## wave 6 (mid-boss), and the Siege Ram closes the run at wave 8.
## Starting ink buys a barracks plus a wall; each clear grants 1 ink and a Royal Decree.
## Wave 1 teaches folding; later waves tighten spacing and trade grunts for specialists
## without increasing the total enemy count or changing their counters.

const LIST := [
	{"grunt": 6, "interval": 1.8},
	{"grunt": 8, "interval": 1.55},
	{"grunt": 6, "runner": 3, "pinner": 1, "interval": 1.4},
	{"grunt": 6, "runner": 3, "brute": 2, "flyer": 2, "interval": 1.3},
	{"grunt": 6, "runner": 3, "brute": 1, "flyer": 2, "imp": 2, "interval": 1.25},
	{"grunt": 4, "runner": 2, "brute": 2, "warlord": 1, "interval": 1.35, "boss": true},
	{"grunt": 6, "runner": 5, "brute": 3, "pinner": 1, "flyer": 2, "interval": 1.2},
	{"grunt": 4, "runner": 4, "brute": 3, "flyer": 2, "imp": 1, "ram": 1, "interval": 1.2, "boss": true},
]

const START_INK := 8
const WAVE_BONUS_INK := 1
const COSTS := {"tower": 4, "wall": 3, "barracks": 5, "archer_tower": 6}
const SQUAD_SIZE := 2 ## knights per barracks
const KNIGHT_RESPAWN := 6.0 ## seconds, during waves
const REWARDS := {"grunt": 1, "runner": 1, "brute": 2, "ram": 6, "pinner": 2, "flyer": 1, "imp": 1, "warlord": 5}
const KEEP_DAMAGE := {"grunt": 1, "runner": 1, "brute": 3, "ram": 5, "flyer": 2, "warlord": 4}
## Spawn-queue order of every enemy kind a wave may list.
const KINDS := ["grunt", "runner", "brute", "pinner", "flyer", "imp", "warlord", "ram"]
const BOSSES := {"warlord": "THE IRON WARLORD!", "ram": "THE SIEGE RAM!"}
const KEEP_SLAM_COST := 1
const KEEP_MAX_HP := 10


## Shuffled spawn queue of enemy kinds for wave i (0-based).
static func queue_for(i: int) -> Array[String]:
	var q: Array[String] = []
	for kind in KINDS:
		for n in LIST[i].get(kind, 0):
			q.append(kind)
	q.shuffle()
	# never open a wave with a brute
	if q.size() > 1 and q[0] == "brute":
		var j := q.find("grunt")
		if j > 0:
			q[0] = "grunt"
			q[j] = "brute"
	# the boss arrives after a short opening
	for boss: String in BOSSES:
		var r := q.find(boss)
		if r >= 0:
			q.remove_at(r)
			q.insert(mini(4, q.size()), boss)
	return q
