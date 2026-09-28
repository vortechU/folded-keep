class_name Waves
## Wave table. Tune freely (owner: Helper, task 13). Counts per enemy kind + seconds between spawns.

const LIST := [
	{"grunt": 6, "interval": 1.6},
	{"grunt": 10, "interval": 1.3},
	{"grunt": 8, "runner": 4, "interval": 1.1},
	{"grunt": 10, "runner": 4, "brute": 2, "interval": 1.0},
	{"grunt": 12, "runner": 6, "brute": 3, "interval": 0.9},
	{"grunt": 14, "runner": 8, "brute": 5, "interval": 0.8},
	{"grunt": 8, "runner": 6, "brute": 2, "ram": 1, "interval": 1.0, "boss": true},
]

const START_INK := 8
const WAVE_BONUS_INK := 3
const COSTS := {"tower": 4, "wall": 3, "barracks": 5}
const SQUAD_SIZE := 2 ## knights per barracks
const KNIGHT_RESPAWN := 6.0 ## seconds, during waves
const REWARDS := {"grunt": 1, "runner": 1, "brute": 3, "ram": 10}
const KEEP_DAMAGE := {"grunt": 1, "runner": 1, "brute": 3, "ram": 5}
const KEEP_SLAM_COST := 1
const KEEP_MAX_HP := 10


## Shuffled spawn queue of enemy kinds for wave i (0-based).
static func queue_for(i: int) -> Array[String]:
	var q: Array[String] = []
	for kind in ["grunt", "runner", "brute", "ram"]:
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
