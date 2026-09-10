class_name Achievements
extends RefCounted

## Achievement catalogue. GameState owns which are unlocked and checks conditions
## against the saved stats; each grants a one-time coin reward.

const LIST: Dictionary = {
	"first_win": {"name": "First Win",      "desc": "Win a match",            "reward": 50},
	"fifty":     {"name": "Half Century",   "desc": "Make a break of 50+",    "reward": 75},
	"century":   {"name": "Century Maker",  "desc": "Make a break of 100+",   "reward": 150},
	"pots100":   {"name": "Sharp Shooter",  "desc": "Pot 100 balls in total", "reward": 100},
	"wins3":     {"name": "Hustler",        "desc": "Win 3 matches",          "reward": 100},
	"play10":    {"name": "Table Regular",  "desc": "Play 10 matches",        "reward": 75},
}
const ORDER: Array = ["first_win", "fifty", "century", "pots100", "wins3", "play10"]
