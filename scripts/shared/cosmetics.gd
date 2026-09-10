class_name Cosmetics
extends RefCounted

## Catalogue of unlockable cosmetics (table cloths and cue skins). Purely data;
## GameState owns what's unlocked/selected and the coin balance.

const CLOTHS: Dictionary = {
	"green":    {"name": "Classic Green", "price": 0,   "color": Color(0.055, 0.42, 0.22)},
	"blue":     {"name": "Royal Blue",    "price": 150, "color": Color(0.09, 0.30, 0.52)},
	"maroon":   {"name": "Maroon",        "price": 150, "color": Color(0.42, 0.10, 0.14)},
	"purple":   {"name": "Purple",        "price": 200, "color": Color(0.28, 0.13, 0.44)},
	"charcoal": {"name": "Charcoal",      "price": 250, "color": Color(0.16, 0.18, 0.21)},
}
const CLOTH_ORDER: Array = ["green", "blue", "maroon", "purple", "charcoal"]

const CUES: Dictionary = {
	"classic": {"name": "Classic", "price": 0,   "color": Color(0.86, 0.66, 0.36)},
	"maple":   {"name": "Maple",   "price": 100, "color": Color(0.82, 0.66, 0.44)},
	"ebony":   {"name": "Ebony",   "price": 120, "color": Color(0.16, 0.13, 0.11)},
	"crimson": {"name": "Crimson", "price": 150, "color": Color(0.72, 0.20, 0.16)},
	"azure":   {"name": "Azure",   "price": 150, "color": Color(0.20, 0.42, 0.78)},
}
const CUE_ORDER: Array = ["classic", "maple", "ebony", "crimson", "azure"]
