class_name Waves
## Six steadily growing waves, then a smaller escort around the three-crush boss.
## The slower cadence leaves time to fold without stacking up tears; starting ink
## buys a barracks plus a wall, and each clear grants another 3 ink before kills.

const LIST := [
	{"grunt": 6, "interval": 1.8},
	{"grunt": 8, "interval": 1.7},
	{"grunt": 8, "runner": 2, "pinner": 1, "interval": 1.6},
	{"grunt": 8, "runner": 3, "brute": 1, "flyer": 2, "interval": 1.5},
	{"grunt": 8, "runner": 4, "brute": 2, "imp": 2, "interval": 1.4},
	{"grunt": 8, "runner": 5, "brute": 3, "interval": 1.3},
	{"grunt": 4, "runner": 2, "brute": 1, "ram": 1, "interval": 1.5, "boss": true},
]

const START_INK := 8
const WAVE_BONUS_INK := 3
const COSTS := {"tower": 4, "wall": 3, "barracks": 5}
const SQUAD_SIZE := 2 ## knights per barracks
const KNIGHT_RESPAWN := 6.0 ## seconds, during waves
const REWARDS := {"grunt": 1, "runner": 1, "brute": 3, "ram": 10, "pinner": 3, "flyer": 2, "imp": 2}
const KEEP_DAMAGE := {"grunt": 1, "runner": 1, "brute": 3, "ram": 5, "flyer": 2}
## Spawn-queue order of every enemy kind a wave may list.
const KINDS := ["grunt", "runner", "brute", "pinner", "flyer", "imp", "ram"]
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
	var r := q.find("ram")
	if r >= 0:
		q.remove_at(r)
		q.insert(mini(4, q.size()), "ram")
	return q
