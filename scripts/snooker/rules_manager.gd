class_name RulesManager
extends RefCounted

## Core snooker rules for a single frame.
##
## Two phases:
##   REDS    — reds still on the table. The striker alternates: pot a red
##             (1 pt each), then a colour (respotted), then a red, and so on.
##   COLOURS — all reds gone. The colours must be potted in ascending order
##             (yellow 2 → black 7) and are removed permanently.
##
## evaluate() is fed what happened during a shot (first ball the cue touched,
## the balls potted, whether the cue ball went in) and returns the outcome:
## score, foul, whether the striker keeps their turn, which colours to respot,
## and whether the frame is over. It also advances the internal on-ball state.

enum Phase { REDS, COLOURS }

const FOUL_MIN: int = 4
const COLOUR_ORDER: Array[int] = [2, 3, 4, 5, 6, 7]   # yellow..black values
const COLOUR_NAMES: Dictionary = {
	2: "YELLOW", 3: "GREEN", 4: "BROWN", 5: "BLUE", 6: "PINK", 7: "BLACK",
}

var reds_remaining: int = 15
var on_red: bool = true            # REDS phase: is a red the ball "on"?
var phase: int = Phase.REDS
var next_colour: int = 2           # COLOURS phase: value of the ball "on"
var frame_complete: bool = false
var free_ball: bool = false        # Pro rules: this shot is on a free ball.


func reset(reds: int) -> void:
	reds_remaining = reds
	on_red = true
	phase = Phase.REDS
	next_colour = 2
	frame_complete = false
	free_ball = false


func on_ball_text() -> String:
	if frame_complete:
		return "Frame over"
	var base: String
	if phase == Phase.COLOURS:
		base = COLOUR_NAMES.get(next_colour, "-")
	else:
		base = "RED" if on_red else "COLOUR"
	return "FREE • " + base if free_ball else base


## Evaluate a finished shot.
##   first        : Ball the cue ball first contacted, or null.
##   potted       : Array of potted balls, EXCLUDING the cue ball.
##   cue_potted   : true if the cue ball was potted (in-off).
## Returns a Dictionary (see keys assembled below).
func evaluate(first, potted: Array, cue_potted: bool) -> Dictionary:
	var res: Dictionary = {
		"foul": false, "foul_value": 0, "score": 0,
		"keep_turn": false, "respot": [], "frame_complete": false,
	}

	var reds: Array = []
	var colours: Array = []
	for b in potted:
		if b.type == Ball.BallType.RED:
			reds.append(b)
		else:
			colours.append(b)

	# Pro rules: a free ball relaxes the "ball on" for this one shot — the striker
	# may hit and pot any ball, and it scores the value of the ball that was on.
	if free_ball:
		return _eval_free_ball(first, reds, colours, cue_potted, res)

	var foul: bool = false
	var offend: int = 0            # Highest value involved in a foul.

	if cue_potted:
		foul = true
	if first == null:
		foul = true

	if phase == Phase.REDS:
		if on_red:
			# Ball on is a red: hit a red first, pot only reds.
			if first != null and first.type != Ball.BallType.RED:
				foul = true
				offend = maxi(offend, first.value)
			if colours.size() > 0:
				foul = true
				for c in colours:
					offend = maxi(offend, c.value)
			if not foul and reds.size() > 0:
				res["score"] = reds.size()          # 1 point per red.
				reds_remaining -= reds.size()
				on_red = false
				res["keep_turn"] = true
		else:
			# Ball on is a colour (any): hit a colour first, pot exactly one.
			if first != null and first.type == Ball.BallType.RED:
				foul = true
				offend = maxi(offend, 1)
			if reds.size() > 0:
				foul = true
			if colours.size() > 1:
				foul = true
				for c in colours:
					offend = maxi(offend, c.value)
			if not foul and colours.size() == 1:
				res["score"] = colours[0].value
				res["respot"].append(colours[0])    # Colour respots (reds remain).
				on_red = true
				if reds_remaining <= 0:              # Last red already gone.
					phase = Phase.COLOURS
					next_colour = 2
				res["keep_turn"] = true
	else:
		# COLOURS phase: only the ball on (next_colour) is legal.
		if first != null and first.value != next_colour:
			foul = true
			offend = maxi(offend, maxi(first.value, next_colour))
		if reds.size() > 0:
			foul = true
		for c in colours:
			if c.value != next_colour:
				foul = true
				offend = maxi(offend, c.value)
		if not foul:
			var potted_on: bool = false
			for c in colours:
				if c.value == next_colour:
					potted_on = true
			if potted_on:
				res["score"] = next_colour          # Removed permanently.
				_advance_colour()
				res["keep_turn"] = true
				if next_colour > 7:
					frame_complete = true
					res["frame_complete"] = true

	if foul:
		res["foul"] = true
		res["keep_turn"] = false
		res["score"] = 0
		res["foul_value"] = maxi(FOUL_MIN, maxi(_on_value(), offend))
		res["respot"] = colours.duplicate()          # All potted colours respot.
		reds_remaining -= reds.size()                # Fouled reds stay down, no score.

	# If the reds are gone but we're still "on a red" (e.g. the last red went in
	# on a foul), the game moves to the colours sequence — yellow is next on.
	if phase == Phase.REDS and reds_remaining <= 0 and on_red:
		phase = Phase.COLOURS
		next_colour = 2

	return res


## Evaluate a shot taken on a free ball. Any ball may be struck; potting exactly
## one ball scores the value of the ball that was on, and the potted ball is
## respotted (it was only nominated, never the real object ball being cleared).
func _eval_free_ball(first, reds: Array, colours: Array, cue_potted: bool, res: Dictionary) -> Dictionary:
	free_ball = false
	var potted_count: int = reds.size() + colours.size()
	var foul: bool = cue_potted or first == null or potted_count > 1

	if foul:
		res["foul"] = true
		res["keep_turn"] = false
		res["score"] = 0
		res["foul_value"] = maxi(FOUL_MIN, _on_value())
		res["respot"] = colours.duplicate()          # potted colours go back up
		reds_remaining -= reds.size()                # any fouled reds stay down
		_post_eval_phase()
		return res

	if potted_count == 0:                            # a legal safety off the free ball
		res["keep_turn"] = false
		return res

	# Exactly one ball potted — it counts as the ball on.
	var potted_ball = reds[0] if reds.size() == 1 else colours[0]
	res["keep_turn"] = true
	if phase == Phase.COLOURS:
		res["score"] = next_colour                   # scores the colour that was on
		res["respot"].append(potted_ball)            # nominated ball respots
	elif on_red:
		res["score"] = 1                             # a red is worth one
		if potted_ball.type == Ball.BallType.RED:
			reds_remaining -= 1                       # an actual red really goes down
		else:
			res["respot"].append(potted_ball)        # a colour-as-red respots
		on_red = false
	else:
		res["score"] = potted_ball.value             # nominated colour's value
		res["respot"].append(potted_ball)
		on_red = true

	_post_eval_phase()
	return res


## Move to the colours sequence once the reds are exhausted while on a red.
func _post_eval_phase() -> void:
	if phase == Phase.REDS and reds_remaining <= 0 and on_red:
		phase = Phase.COLOURS
		next_colour = 2


func _on_value() -> int:
	if phase == Phase.COLOURS:
		return next_colour
	return 1 if on_red else FOUL_MIN


func _advance_colour() -> void:
	var idx: int = COLOUR_ORDER.find(next_colour)
	if idx >= 0 and idx + 1 < COLOUR_ORDER.size():
		next_colour = COLOUR_ORDER[idx + 1]
	else:
		next_colour = 8    # All colours cleared -> frame over.
