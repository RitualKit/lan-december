extends Node
## Match state: who is playing, which minigames run in which order, and the scores.

signal players_changed

const MAX_PLAYERS := 8
## Points for 1st, 2nd, 3rd... in a round. Ties share the better placement.
const PLACEMENT_POINTS: Array[int] = [10, 7, 5, 3, 2, 1, 0, 0]
const ROUND_CHOICES: Array[int] = [5, 10, 15]
## Last rounds are worth double so nobody is out of it until the end.
const DOUBLE_POINT_ROUNDS := 2

const MINIGAMES: Array[String] = [
	"res://minigames/petal_push.gd",
	"res://minigames/petal_rush.gd",
	"res://minigames/hot_lantern.gd",
	"res://minigames/crumble.gd",
	"res://minigames/blossom_king.gd",
	"res://minigames/rockfall.gd",
	"res://minigames/paint_the_isle.gd",
	"res://minigames/koi_catch.gd",
	"res://minigames/river_run.gd",
	"res://minigames/snowball_fight.gd",
	"res://minigames/stump_scramble.gd",
	"res://minigames/color_call.gd",
	"res://minigames/monster_bonk.gd",
]

var players: Array[PlayerSlot] = []
var rounds_total := 10
var round_number := 0 ## 1-based, 0 before the first round.
var round_plan: Array[String] = []
var rng := RandomNumberGenerator.new()
## Forces every arena to one theme (screenshots/tests); "" = rotate through Themes.
var theme_override := ""
var _theme_bag: Array[String] = []
## Set by the main scene; used to switch screens.
var main: Node


func _ready() -> void:
	rng.randomize()


func add_player(device: String, bot := false) -> PlayerSlot:
	if players.size() >= MAX_PLAYERS:
		return null
	var used := {}
	for p in players:
		used[p.id] = true
	var id := 0
	while used.has(id):
		id += 1
	var slot := PlayerSlot.new(id, device, bot)
	slot.skill = rng.randf_range(0.55, 0.95)
	slot.character = next_free_character(-1)
	players.append(slot)
	players.sort_custom(func(a, b): return a.id < b.id)
	players_changed.emit()
	return slot


## The next character after `after` that nobody is using.
func next_free_character(after: int) -> int:
	var used := {}
	for p in players:
		used[p.character] = true
	var n := Art.CHARACTERS.size()
	for step in range(1, n + 1):
		var c := posmod(after + step, n)
		if not used.has(c):
			return c
	return posmod(after + 1, n)


func remove_player(slot: PlayerSlot) -> void:
	players.erase(slot)
	players_changed.emit()


func remove_bot() -> void:
	for i in range(players.size() - 1, -1, -1):
		if players[i].is_bot:
			remove_player(players[i])
			return


func player_for_device(device: String) -> PlayerSlot:
	for p in players:
		if not p.is_bot and p.device == device:
			return p
	return null


func human_count() -> int:
	return players.filter(func(p): return not p.is_bot).size()


## Shuffle-bag order: every minigame plays once before any repeats,
## and the same game never plays twice in a row.
func plan_rounds() -> void:
	round_plan.clear()
	var last := ""
	while round_plan.size() < rounds_total:
		var bag := MINIGAMES.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: String = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		if bag[0] == last and bag.size() > 1:
			bag.push_back(bag.pop_front())
		for path in bag:
			if round_plan.size() < rounds_total:
				round_plan.append(path)
		last = round_plan[-1]


## Next island theme, shuffle-bag style so consecutive rounds look different.
func next_theme() -> String:
	if theme_override != "":
		return theme_override
	if _theme_bag.is_empty():
		_theme_bag = Themes.ORDER.duplicate()
		_theme_bag.shuffle()
	return _theme_bag.pop_back()


func reset_scores() -> void:
	round_number = 0
	for p in players:
		p.score = 0
		p.last_points = 0
		p.round_wins = 0


func start_match() -> void:
	reset_scores()
	plan_rounds()
	if main:
		main.goto_match()


func multiplier(round_no := round_number) -> int:
	return 2 if round_no > rounds_total - DOUBLE_POINT_ROUNDS else 1


## ranking: Array of Arrays of PlayerSlot, best group first. Returns PlayerSlot -> points.
func award(ranking: Array, mult := 1) -> Dictionary:
	var out := {}
	var place := 0
	for group in ranking:
		var pts: int = PLACEMENT_POINTS[mini(place, PLACEMENT_POINTS.size() - 1)] * mult
		for slot in group:
			out[slot] = pts
			slot.last_points = pts
			slot.score += pts
			if place == 0:
				slot.round_wins += 1
		place += group.size()
	return out


## Players sorted by score (then round wins), best first.
func standings() -> Array[PlayerSlot]:
	var out := players.duplicate()
	out.sort_custom(func(a, b):
		if a.score != b.score:
			return a.score > b.score
		return a.round_wins > b.round_wins)
	return out


## Groups players with identical score into tied placements.
static func group_by_score(slots: Array, scores: Dictionary, higher_is_better := true) -> Array:
	var sorted := slots.duplicate()
	sorted.sort_custom(func(a, b):
		return scores.get(a, 0) > scores.get(b, 0) if higher_is_better else scores.get(a, 0) < scores.get(b, 0))
	var groups := []
	for s in sorted:
		if groups.is_empty() or not is_equal_approx(float(scores.get(groups[-1][0], 0)), float(scores.get(s, 0))):
			groups.append([s])
		else:
			groups[-1].append(s)
	return groups
