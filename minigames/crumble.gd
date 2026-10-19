extends Minigame
## Tiles crack the first time you step on them and crumble the second time.
## Standing still crumbles them too. Hop over gaps and outlast everyone.

const CRACK_DELAY := 0.45
const CAMP_TIME := 1.1

var hits := {} ## ArenaTile -> number of separate visits
var _on := {} ## PlayerCharacter -> [tile, time on it]


func _init() -> void:
	title = "Crumble"
	tagline = "The ground falls away behind you!"
	rules = [
		"Tiles crack when you step on them and crumble the next time.",
		"Standing still crumbles your tile too. Keep moving!",
		"Press action to hop over gaps. Last one standing wins.",
	]
	action_name = "Hop"
	accent = Color("d8c08c")
	time_limit = 90.0
	last_standing = true
	bump_power = 4.0


func build() -> void:
	var big := players.size() > 4
	var w := 13 if big else 11
	var h := 11 if big else 9
	arena.build(Arena.rect(w, h), "path")
	arena.setup_view(Vector3.ZERO, 16.0 + w * 0.75)
	arena.decorate(rng.randi(), maxf(w, h) * 0.6)
	spawn_characters(arena.spawn_ring(players.size(), minf(w, h) * 0.33))
	for ch in chars:
		ch.can_dash = false
		ch.can_jump = true
		ch.speed = 4.2


func tick(delta: float) -> void:
	for ch in chars:
		if not ch.alive or not ch.is_on_floor():
			continue
		var t := arena.tile_at(ch.global_position)
		if t == null or t.state != ArenaTile.State.SOLID:
			continue
		var prev: Array = _on.get(ch, [null, 0.0])
		if prev[0] != t:
			_on[ch] = [t, 0.0]
			hits[t] = hits.get(t, 0) + 1
			if hits[t] == 1:
				t.set_top("path_cracked")
				Sfx.play_varied("crack", 0.3, -16.0)
			else:
				_crumble(t)
		else:
			prev[1] += delta
			if prev[1] > CAMP_TIME:
				_crumble(t)


func _crumble(t: ArenaTile) -> void:
	t.crack(CRACK_DELAY)
	Sfx.play_varied("crack", 0.3, -10.0)


## 2 = untouched, 1 = cracked, 0 = gone/crumbling.
func _tile_health(cell: Vector2i) -> int:
	var t: ArenaTile = arena.tiles.get(cell)
	if t == null or t.state != ArenaTile.State.SOLID:
		return 0
	return 2 - mini(1, hits.get(t, 0))


func _tile_ok(cell: Vector2i) -> bool:
	return _tile_health(cell) > 0


## How much floor is around a cell (two rings deep), untouched tiles counting double.
func _room(cell: Vector2i) -> float:
	var hp := _tile_health(cell)
	if hp == 0:
		return -1.0
	var score := hp * 2.0
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var near := absi(dx) + absi(dz) <= 2
			score += _tile_health(cell + Vector2i(dx, dz)) * (0.5 if near else 0.25)
	return score


const DIRS8 := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]


## CPUs walk tile to tile, always onto an untouched neighbour with the most room
## around it, and hop a gap when no neighbour is left.
func bot_input(ch: PlayerCharacter) -> Dictionary:
	var m := mem(ch)
	var here := Vector2i(roundi(ch.global_position.x), roundi(ch.global_position.z))
	var goal_ok: bool = m.has("goal") and _tile_ok(m.goal)
	var reached: bool = m.has("goal") and Vector2(ch.global_position.x - m.goal.x, ch.global_position.z - m.goal.y).length() < 0.25
	if ch.is_on_floor() and (not goal_ok or reached):
		var best := here
		var best_s := -INF
		var hop := false
		var sloppiness := 3.0 * (1.1 - ch.slot.skill)
		for d in DIRS8:
			var c: Vector2i = here + d
			if _tile_ok(c):
				var s := _room(c) + rng.randf() * sloppiness
				if s > best_s:
					best_s = s
					best = c
		if best == here:
			for d in DIRS8:
				var c: Vector2i = here + d * 2
				if _tile_ok(c):
					var s := _room(c) + rng.randf() * sloppiness
					if s > best_s:
						best_s = s
						best = c
						hop = true
		m.goal = best
		m.hop = hop
	if not m.has("goal"):
		return {"move": Vector2.ZERO, "action": false, "hold": false}
	var goal: Vector2i = m.goal
	var d := Vector3(goal.x, 0, goal.y) - ch.global_position
	d.y = 0.0
	var move := Vector2(d.x, d.z).normalized() if d.length() > 0.08 else Vector2.ZERO
	var jump: bool = m.get("hop", false) and ch.is_on_floor() and not arena.is_safe(ch.global_position + Vector3(move.x, 0, move.y) * 0.55)
	if jump:
		m.hop = false
	return {"move": move, "action": jump, "hold": false}
