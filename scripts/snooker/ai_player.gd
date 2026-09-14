class_name AIPlayer
extends RefCounted

## A snooker opponent. For every legal target ball and every pocket it works out
## the "ghost ball" line (where the cue ball must be at contact to send the
## target to that pocket), rejects impossible cuts and blocked paths, then scores
## the rest — rewarding easy angles, penalising in-off (scratch) risk, and (on
## Hard) rewarding shots that leave the cue ball on the next ball. If nothing is
## on, it plays a safety that returns the cue ball toward baulk.
##
## Difficulty changes both the aim error AND the decision quality:
##   Easy   — big error, often picks a worse shot, cares little about scratching.
##   Medium — moderate error, usually the best shot.
##   Hard   — small error, best shot, avoids scratches, plays position & control.

var difficulty: int = 1                       # 0 Easy, 1 Medium, 2 Hard.

const AIM_ERROR := [0.115, 0.045, 0.008]      # radians of aim wobble (Hard barely misses).
const POWER_JITTER := [[0.84, 1.16], [0.93, 1.07], [0.98, 1.03]]
const SCRATCH_PEN := [0.6, 1.9, 4.2]          # penalty for an in-off risk.
const CUT_MIN := 0.18                          # thinnest cut geometrically attempted.
# If the BEST available pot's makeability is below this, play safe instead of
# hacking at a low-percentage shot (0 = always attempt, like a beginner).
const MAKE_MIN := [0.0, 0.20, 0.32]


func choose_shot(game) -> Dictionary:
	var cue: Ball = game.cue_ball
	var radius: float = game.ball_radius
	var targets := _legal_targets(game)
	var d := clampi(difficulty, 0, 2)

	var cands: Array = []
	for t in targets:
		for p in game.table.pockets:
			var c := _eval_pot(game, cue, t, p["pos"], radius, targets, d)
			if not c.is_empty():
				cands.append(c)

	if not cands.is_empty():
		cands.sort_custom(func(a, b): return a["score"] > b["score"])
		# Better players decline a low-percentage pot and play safe instead.
		if float(cands[0].get("make", 1.0)) < MAKE_MIN[d]:
			return _safety(game, cue, targets, d)
		var idx := 0
		if d == 0:
			idx = randi() % mini(cands.size(), 4)          # Easy: any of the top few.
		elif d == 1 and randf() < 0.22:
			idx = mini(1, cands.size() - 1)                # Medium: sometimes 2nd best.
		var pick: Dictionary = cands[idx]
		var err: float = AIM_ERROR[d]
		var dir: Vector2 = pick["dir"].rotated(randf_range(-err, err))
		var jit: Array = POWER_JITTER[d]
		var power: float = clampf(pick["power"] * randf_range(jit[0], jit[1]), 0.14, 1.0)
		return {"dir": dir, "power": power, "side": 0.0, "follow": pick.get("follow", 0.0)}

	return _safety(game, cue, targets, d)


func _legal_targets(game) -> Array:
	var out: Array = []
	var rules = game.rules
	if rules.phase == RulesManager.Phase.COLOURS:
		for b in game.balls:
			if not b.is_potted and b.value == rules.next_colour and b.type != Ball.BallType.CUE:
				out.append(b)
	elif rules.on_red:
		for b in game.balls:
			if not b.is_potted and b.type == Ball.BallType.RED:
				out.append(b)
	else:
		for b in game.balls:
			if not b.is_potted and b.type != Ball.BallType.RED and b.type != Ball.BallType.CUE:
				out.append(b)
	return out


## Evaluate potting `target` into `pocket`. Returns {} if not viable.
func _eval_pot(game, cue: Ball, target: Ball, pocket: Vector2, radius: float, targets: Array, d: int) -> Dictionary:
	var pot_dir := pocket - target.position
	var tp_dist := pot_dir.length()
	if tp_dist < 1.0:
		return {}
	pot_dir /= tp_dist

	var ghost := target.position - pot_dir * (2.0 * radius)
	var aim := ghost - cue.position
	var aim_dist := aim.length()
	if aim_dist < 1.0:
		return {}
	aim /= aim_dist

	var cut := aim.dot(pot_dir)              # 1 = straight, 0 = 90° (impossible).
	if cut <= CUT_MIN:
		return {}

	# Paths must be roughly clear.
	if _blocked(game, cue.position, ghost, [cue, target], radius):
		return {}
	if _blocked(game, target.position, pocket, [target], radius):
		return {}

	var need := aim_dist + tp_dist
	var power := clampf(need / 1700.0 / maxf(cut, 0.3), 0.22, 1.0)

	# Makeability (0..1): straight AND short pots are easy; thin/long ones are not.
	# This is the dominant term, so the bot prefers high-percentage shots.
	var dist_factor := clampf(1.0 - need / 2400.0, 0.12, 1.0)
	var make := cut * cut * dist_factor          # square the cut so thin cuts drop off fast
	var score := make * 3.0 + target.value * 0.05

	# The cue ball leaves along the tangent (perpendicular to the line of centres).
	var after := aim - aim.dot(pot_dir) * pot_dir
	var follow := 0.0
	if after.length() > 0.05:
		after = after.normalized()
		if _scratch_risk(game, ghost, after, radius):
			score -= SCRATCH_PEN[d]
		# Position is only a tie-breaker among already-makeable shots (× make),
		# so the bot never picks a hard pot just for shape.
		if d == 2 and make > 0.30:
			score += _position_bonus(contact_after(ghost, after, radius), after, target, targets) * make

	return {"dir": aim, "power": power, "score": score, "follow": follow, "make": make}


func contact_after(ghost: Vector2, after: Vector2, radius: float) -> Vector2:
	return ghost + after * (radius * 2.0)


## True if the cue ball's post-contact path runs into a pocket (in-off).
func _scratch_risk(game, from: Vector2, dir: Vector2, radius: float) -> bool:
	var pr: float = game.table.pocket_radius
	for p in game.table.pockets:
		var to_p: Vector2 = p["pos"] - from
		var t := to_p.dot(dir)
		if t > 20.0 and t < 1100.0:
			var perp := (to_p - dir * t).length()
			if perp < pr * 1.25:
				return true
	return false


## Reward (Hard) if the cue ball's tangent path passes close to another legal
## ball — i.e. the bot "gets on" the next shot.
func _position_bonus(from: Vector2, dir: Vector2, target: Ball, targets: Array) -> float:
	var best := 0.0
	for t in targets:
		if t == target:
			continue
		var to_t: Vector2 = t.position - from
		var along := to_t.dot(dir)
		if along > 60.0 and along < 900.0:
			var perp := (to_t - dir * along).length()
			if perp < 130.0:
				best = maxf(best, 0.6 * (1.0 - perp / 130.0))
	return best


## No pot available — play a safety: hit the ball on and (on Hard) draw the cue
## ball back toward the baulk end rather than leaving an easy return.
func _safety(game, cue: Ball, targets: Array, d: int) -> Dictionary:
	var nearest: Ball = null
	var best := INF
	for t in targets:
		var dd := cue.position.distance_to(t.position)
		if dd < best:
			best = dd
			nearest = t
	if nearest == null:
		return {"dir": Vector2(-1, 0), "power": 0.30, "side": 0.0, "follow": 0.0}
	var dir := (nearest.position - cue.position).normalized()
	var power := 0.30 if d == 2 else 0.40    # Hard controls pace better.
	var follow := -0.30 if d == 2 else 0.0   # draw brings the cue ball back.
	return {"dir": dir, "power": power, "side": 0.0, "follow": follow}


## True if any (non-ignored) ball is close enough to the segment to block it.
func _blocked(game, from: Vector2, to: Vector2, ignore: Array, radius: float) -> bool:
	for b in game.balls:
		if b.is_potted or b in ignore:
			continue
		if _seg_dist(from, to, b.position) < 2.0 * radius - 2.0:
			return true
	return false


func _seg_dist(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
