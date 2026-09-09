class_name AIPlayer
extends RefCounted

## A simple snooker opponent. For every legal target ball and every pocket it
## works out the "ghost ball" line (where the cue ball must be at contact to send
## the target to that pocket), rejects impossible cuts and blocked paths, scores
## the rest, and takes the best. If nothing is on, it plays a soft safety so it
## at least hits the right ball first. Difficulty adds aiming error.

var difficulty: int = 1          # 0 Easy, 1 Medium, 2 Hard.

const AIM_ERROR := [0.10, 0.05, 0.022]   # radians, per difficulty


func choose_shot(game) -> Dictionary:
	var cue: Ball = game.cue_ball
	var radius: float = game.ball_radius
	var targets := _legal_targets(game)

	var best: Dictionary = {}
	var best_score := -INF
	for t in targets:
		for p in game.table.pockets:
			var cand := _eval_pot(game, cue, t, p["pos"], radius)
			if not cand.is_empty() and cand["score"] > best_score:
				best_score = cand["score"]
				best = cand

	if not best.is_empty():
		var err: float = AIM_ERROR[clampi(difficulty, 0, 2)]
		var dir: Vector2 = best["dir"].rotated(randf_range(-err, err))
		var power: float = clampf(best["power"] * randf_range(0.96, 1.06), 0.15, 1.0)
		return {"dir": dir, "power": power, "side": 0.0, "follow": 0.0}

	return _safety(game, cue, targets)


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
func _eval_pot(game, cue: Ball, target: Ball, pocket: Vector2, radius: float) -> Dictionary:
	var pot_dir := (pocket - target.position)
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

	var cut := aim.dot(pot_dir)          # 1 = straight, 0 = 90° (impossible).
	if cut <= 0.20:
		return {}

	# Paths must be roughly clear.
	if _blocked(game, cue.position, ghost, [cue, target], radius):
		return {}
	if _blocked(game, target.position, pocket, [target], radius):
		return {}

	var need := aim_dist + tp_dist
	var power := clampf(need / 1700.0 / maxf(cut, 0.3), 0.22, 1.0)
	# Prefer makeable (straight, short) shots, and — when there's a choice of
	# legal balls — the higher-value one.
	var score := cut * 2.0 - need / 2200.0 + target.value * 0.10
	return {"dir": aim, "power": power, "score": score}


func _safety(game, cue: Ball, targets: Array) -> Dictionary:
	var nearest: Ball = null
	var best := INF
	for t in targets:
		var dd := cue.position.distance_to(t.position)
		if dd < best:
			best = dd
			nearest = t
	if nearest == null:
		return {"dir": Vector2(1, 0), "power": 0.3, "side": 0.0, "follow": 0.0}
	var dir := (nearest.position - cue.position).normalized()
	return {"dir": dir, "power": 0.38, "side": 0.0, "follow": 0.0}


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
