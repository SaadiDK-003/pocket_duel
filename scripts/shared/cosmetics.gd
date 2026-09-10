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

## Ball sets change the finish (rendered by BallPainter) applied to every ball.
## `style` is the finish key; `color` is the swatch/preview base (a red ball).
const BALL_SETS: Dictionary = {
	"set_classic": {"name": "Classic", "price": 0,   "style": "classic", "color": Color(0.80, 0.09, 0.09)},
	"set_matte":   {"name": "Matte",   "price": 120, "style": "matte",   "color": Color(0.80, 0.09, 0.09)},
	"set_marble":  {"name": "Marble",  "price": 180, "style": "marble",  "color": Color(0.80, 0.09, 0.09)},
	"set_neon":    {"name": "Neon",    "price": 240, "style": "neon",    "color": Color(0.90, 0.12, 0.12)},
}
const BALL_SET_ORDER: Array = ["set_classic", "set_matte", "set_marble", "set_neon"]
