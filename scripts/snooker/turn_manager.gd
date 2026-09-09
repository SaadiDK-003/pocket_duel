class_name TurnManager
extends RefCounted

## Two-player state for a local frame: names, scores, and whose turn it is.
## Pure data — the game manager drives it and the HUD reads it. The full
## snooker rule logic (red/colour sequence, fouls) arrives in Phase 4; this
## just tracks the players.

var names: Array = ["Player 1", "Player 2"]
var scores: Array[int] = [0, 0]
var current: int = 0
var break_score: int = 0        # Points scored in the current unbroken visit.
var frames_won: Array[int] = [0, 0]   # Frames won this match.
var highest_break: Array[int] = [0, 0]   # Best break each player made this match.


func other() -> int:
	return 1 - current


func switch_turn() -> void:
	current = other()
	break_score = 0             # A new visit starts fresh.


func add_score(points: int) -> void:
	scores[current] += points
	break_score += points
	if break_score > highest_break[current]:
		highest_break[current] = break_score


func add_score_to(index: int, points: int) -> void:
	scores[index] += points


## Full match reset (new match): scores, turn, and frames won.
func reset() -> void:
	scores = [0, 0]
	current = 0
	break_score = 0
	frames_won = [0, 0]
	highest_break = [0, 0]


## Per-frame reset: fresh scores, chosen breaker, keep frames won.
func reset_frame(starter: int) -> void:
	scores = [0, 0]
	break_score = 0
	current = starter
