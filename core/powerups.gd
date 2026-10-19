class_name Powerups
extends Node3D
## Treasure chests pop up on the island. Walk into one to grab a random item, then fire
## it with the item button (E / Right Shift / gamepad X). One item at a time.

const ITEMS := {
	"bomb": {"label": "BOMB", "icon": "", "weight": 3},
	"shuriken": {"label": "SHURIKENS", "icon": "items/shuriken", "weight": 3},
	"fire": {"label": "FIRE BLAST", "icon": "items/scroll-fire", "weight": 2},
	"ice": {"label": "FREEZE", "icon": "items/scroll-ice", "weight": 2},
	"thunder": {"label": "THUNDER", "icon": "items/scroll-thunder", "weight": 2},
	"giant": {"label": "GIANT", "icon": "items/scroll-rock", "weight": 2},
	"speed": {"label": "SPEED", "icon": "items/milk-pot", "weight": 2},
	"shield": {"label": "SHIELD", "icon": "items/life-pot", "weight": 2},
}
const PICK_RADIUS := 0.7
const BOMB_RADIUS := 2.2
const FIRE_RADIUS := 2.8
const ICE_RADIUS := 3.8
const BOMB_FLIGHT := 0.55

var mg: Minigame
var allowed: Array = ITEMS.keys()
var interval := Vector2(4.0, 7.0)
var max_chests := 2
var chests: Array[Dictionary] = [] ## {node, pos, age}
var held := {} ## PlayerCharacter -> item name

var _spawn_t := 2.5
var _shots: Array[Dictionary] = []
var _bombs: Array[Dictionary] = []
var _bolts: Array[Dictionary] = []
var _bot_wait := {}


func _init(p_minigame: Minigame) -> void:
	mg = p_minigame


static func icon_of(item: String) -> Texture2D:
	var path: String = ITEMS[item].icon
	if path == "":
		return Art.icon("bomb", Color("4a4458"), Color("ff9a4a"))
	return Art.pack(path)


func _physics_process(delta: float) -> void:
	if not mg.running:
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = mg.rng.randf_range(interval.x, interval.y)
		if chests.size() < max_chests:
			spawn_chest()
	_update_chests(delta)
	_update_shots(delta)
	_update_bombs(delta)
	_update_bolts(delta)


# --- Chests -----------------------------------------------------------------------

func spawn_chest() -> void:
	var tiles := mg.arena.solid_tiles()
	if tiles.is_empty():
		return
	for attempt in 12:
		var t: ArenaTile = tiles[mg.rng.randi() % tiles.size()]
		var pos := Vector3(t.cell.x, t.top_y, t.cell.y)
		if chests.any(func(c): return c.pos.distance_to(pos) < 2.0):
			continue
		if mg.alive_chars().any(func(ch): return ch.global_position.distance_to(pos) < 1.2):
			continue
		var s := Art.pack_sprite("items/little-treasure-chest", 2, Art.PIXEL_SIZE * 1.4)
		mg.arena.add_child(s)
		s.global_position = pos + Vector3.UP * 6.0
		var tw := s.create_tween()
		tw.tween_property(s, "global_position", pos + Vector3.UP * 0.45, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		chests.append({"node": s, "pos": pos, "age": 0.0})
		return


func nearest_chest(ch: PlayerCharacter, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for c in chests:
		var d: float = ch.global_position.distance_to(c.pos)
		if d < best_d:
			best_d = d
			best = c
	return best


func _update_chests(delta: float) -> void:
	for i in range(chests.size() - 1, -1, -1):
		var c := chests[i]
		c.age += delta
		var node: Sprite3D = c.node
		if not mg.arena.is_safe(c.pos):
			node.queue_free()
			chests.remove_at(i)
			continue
		if c.age < 0.45:
			continue
		node.position.y = c.pos.y + 0.45 + sin(c.age * 3.0) * 0.06
		for ch in mg.alive_chars():
			if held.has(ch):
				continue
			var d: Vector3 = ch.global_position - c.pos
			if Vector2(d.x, d.z).length() < PICK_RADIUS and absf(d.y) < 1.0:
				_open(c, ch)
				chests.remove_at(i)
				break


func _open(c: Dictionary, ch: PlayerCharacter) -> void:
	var node: Sprite3D = c.node
	node.frame = 1
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 1.3, 0.12)
	tw.tween_property(node, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(node.queue_free)
	give(ch, _roll())


func _roll() -> String:
	var total := 0
	for item in allowed:
		total += ITEMS[item].weight
	var r := mg.rng.randi_range(1, total)
	for item in allowed:
		r -= ITEMS[item].weight
		if r <= 0:
			return item
	return allowed[0]


func give(ch: PlayerCharacter, item: String) -> void:
	held[ch] = item
	ch.show_item(icon_of(item))
	Sfx.play("powerup", 1.0, -4.0)
	Fx.anim(mg.arena, ch.global_position + Vector3.UP * 0.8, "fx/2", 0.8)
	Fx.popup(mg.arena, ch.global_position + Vector3.UP * 2.2, ITEMS[item].label + "!", Ui.GOLD, 40)


# --- Using items ------------------------------------------------------------------

func use(ch: PlayerCharacter) -> bool:
	if not held.has(ch) or not ch.alive:
		return false
	var item: String = held[ch]
	held.erase(ch)
	ch.show_item(null)
	match item:
		"bomb": _throw_bomb(ch)
		"shuriken": _throw_shurikens(ch)
		"fire": _fire_blast(ch)
		"ice": _freeze(ch)
		"thunder": _thunder(ch)
		"giant":
			ch.add_status("giant", 7.0)
			Sfx.play("magic", 0.8)
			Fx.anim(mg.arena, ch.global_position + Vector3.UP * 0.6, "fx/1", 3.0)
		"speed":
			ch.add_status("speed", 6.0)
			ch.reset_dash_cooldown()
			Sfx.play("powerup", 1.4)
			Fx.anim(mg.arena, ch.global_position + Vector3.UP * 0.4, "fx/18", 1.2)
		"shield":
			ch.add_status("shield", 6.0)
			Sfx.play("magic", 1.3)
			Fx.anim(mg.arena, ch.global_position + Vector3.UP * 0.6, "fx/1", 2.0)
	return true


func _hit(owner: PlayerCharacter, victim: PlayerCharacter, impulse: Vector3, stun: float) -> void:
	if not victim.alive:
		return
	if victim.hit(impulse, stun):
		Sfx.play_varied("hit")
		Fx.anim(mg.arena, victim.global_position + Vector3.UP * 0.6, "fx/7", 1.4, 18.0)
		mg.on_power_hit(owner, victim)
	elif victim.has_status("shield"):
		Sfx.play("blip", 1.8, -4.0)
		Fx.anim(mg.arena, victim.global_position + Vector3.UP * 0.6, "fx/1", 1.6)


func _away(from: Vector3, to: Vector3) -> Vector3:
	var d := to - from
	d.y = 0.0
	if d.length() < 0.05:
		var a := mg.rng.randf() * TAU
		return Vector3(cos(a), 0, sin(a))
	return d.normalized()


func _throw_bomb(ch: PlayerCharacter) -> void:
	var s := Art.icon_sprite("bomb", Color("4a4458"), Color("ff9a4a"), 0.07)
	mg.arena.add_child(s)
	var from := ch.global_position + Vector3.UP * 0.8
	var to := ch.global_position + ch.facing * 4.5
	s.global_position = from
	_bombs.append({"node": s, "owner": ch, "from": from, "to": to, "t": 0.0, "fuse": 0.7})
	Sfx.play("throw", 0.8, -4.0)


func _update_bombs(delta: float) -> void:
	for i in range(_bombs.size() - 1, -1, -1):
		var b := _bombs[i]
		var node: Sprite3D = b.node
		b.t += delta
		if b.t < BOMB_FLIGHT:
			var k: float = b.t / BOMB_FLIGHT
			var p: Vector3 = b.from.lerp(b.to, k)
			p.y = lerpf(b.from.y, b.to.y + 0.3, k) + sin(k * PI) * 2.2
			node.global_position = p
			continue
		var landed: Vector3 = b.to
		var tile := mg.arena.tile_at(landed)
		if tile == null or not tile.is_solid():
			Fx.splash(mg.arena, Vector3(landed.x, Arena.WATER_Y, landed.z))
			Sfx.play_varied("splash", 0.1, -6.0)
			node.queue_free()
			_bombs.remove_at(i)
			continue
		landed.y = tile.top_y
		node.global_position = landed + Vector3.UP * 0.35
		b.fuse -= delta
		node.modulate = Color(3, 1.5, 1.5) if int(b.fuse * 12.0) % 2 == 0 else Color.WHITE
		if b.fuse <= 0.0:
			_explode(b.owner, landed)
			node.queue_free()
			_bombs.remove_at(i)


func _explode(owner: PlayerCharacter, pos: Vector3) -> void:
	Fx.explosion_big(mg.arena, pos, 1.6)
	Sfx.play("boom")
	mg.arena.shake(0.7)
	for c in mg.alive_chars():
		var d := c.global_position - pos
		d.y = 0.0
		if d.length() < BOMB_RADIUS:
			_hit(owner, c, _away(pos, c.global_position) * (16.0 - d.length() * 3.5), 0.5)


func _throw_shurikens(ch: PlayerCharacter) -> void:
	Sfx.play("throw", 1.2)
	for spread in [-0.28, 0.0, 0.28]:
		var dir := ch.facing.rotated(Vector3.UP, spread)
		var s := Art.pack_sprite("items/shuriken", 1, 0.05)
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.rotation_degrees.x = -90.0
		mg.arena.add_child(s)
		s.global_position = ch.global_position + Vector3.UP * 0.5 + dir * 0.4
		_shots.append({"node": s, "owner": ch, "vel": dir * 13.0, "life": 0.7})


func _update_shots(delta: float) -> void:
	for i in range(_shots.size() - 1, -1, -1):
		var s := _shots[i]
		var node: Sprite3D = s.node
		node.global_position += s.vel * delta
		node.rotate_y(delta * 25.0)
		s.life -= delta
		var hit := false
		for c in mg.alive_chars():
			if c == s.owner:
				continue
			var d := c.global_position + Vector3.UP * 0.5 - node.global_position
			if Vector2(d.x, d.z).length() < 0.55 * c.size_scale() and absf(d.y) < 1.0:
				_hit(s.owner, c, (s.vel as Vector3).normalized() * 11.0, 0.45)
				hit = true
				break
		if hit or s.life <= 0.0:
			node.queue_free()
			_shots.remove_at(i)


func _fire_blast(ch: PlayerCharacter) -> void:
	var pos := ch.global_position
	Fx.anim(mg.arena, pos + Vector3.UP * 0.6, "fx/12", 4.5, 12.0)
	Fx.burst(mg.arena, pos + Vector3.UP * 0.4, Color("ff8a3a"), 36, 9.0)
	Sfx.play("boom", 1.3)
	mg.arena.shake(0.5)
	for c in mg.alive_chars():
		if c == ch:
			continue
		var d := c.global_position - pos
		d.y = 0.0
		if d.length() < FIRE_RADIUS:
			_hit(ch, c, _away(pos, c.global_position) * (15.0 - d.length() * 2.5), 0.4)


func _freeze(ch: PlayerCharacter) -> void:
	Sfx.play("magic", 1.1)
	var ring := Fx.anim(mg.arena, ch.global_position + Vector3.UP * 0.5, "fx/1", ICE_RADIUS * 2.2, 12.0)
	if ring:
		ring.modulate = Color(0.6, 0.9, 1.0)
	for c in mg.alive_chars():
		if c == ch or c.has_status("shield"):
			continue
		if c.global_position.distance_to(ch.global_position) < ICE_RADIUS:
			c.add_status("frozen", 2.2)
			c.end_dash()
			Fx.anim(mg.arena, c.global_position + Vector3.UP * 0.6, "fx/15", 1.6)


func _thunder(ch: PlayerCharacter) -> void:
	Sfx.play("magic", 0.7)
	for c in mg.alive_chars():
		if c == ch:
			continue
		var warn := Art.zone_decal(Color("ffe14a"), 0.9, 0.4)
		mg.arena.add_child(warn)
		warn.global_position = c.global_position
		_bolts.append({"owner": ch, "pos": c.global_position, "t": 0.8, "decal": warn})


func _update_bolts(delta: float) -> void:
	for i in range(_bolts.size() - 1, -1, -1):
		var b := _bolts[i]
		b.t -= delta
		var decal: Decal = b.decal
		decal.modulate = Color(1, 1, 1, 1.0 if int(b.t * 14.0) % 2 == 0 else 0.4)
		if b.t > 0.0:
			continue
		decal.queue_free()
		_bolts.remove_at(i)
		var pos: Vector3 = b.pos
		_bolt_visual(pos)
		for c in mg.alive_chars():
			var d := c.global_position - pos
			d.y = 0.0
			if d.length() < 1.0 and c != b.owner:
				_hit(b.owner, c, _away(pos, c.global_position) * 3.0, 1.4)


func _bolt_visual(pos: Vector3) -> void:
	var bolt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 14.0, 0.18)
	bolt.mesh = box
	bolt.material_override = Art.color_material(Color("fff6a0"), 6.0)
	mg.arena.add_child(bolt)
	bolt.global_position = pos + Vector3.UP * 7.0
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "scale", Vector3(0.2, 1, 0.2), 0.18)
	tw.tween_callback(bolt.queue_free)
	Fx.anim(mg.arena, pos + Vector3.UP * 0.5, "fx/4", 2.2, 16.0)
	Sfx.play_varied("boom", 0.1, -8.0)
	mg.arena.shake(0.3)


# --- CPU use ----------------------------------------------------------------------

## Should a CPU fire its item now? Waits a short, skill-based moment after pickup.
func bot_wants_use(ch: PlayerCharacter) -> bool:
	if not held.has(ch):
		return false
	var wait: float = _bot_wait.get(ch, mg.rng.randf_range(0.3, 1.6) * (1.4 - ch.slot.skill))
	wait -= mg.get_physics_process_delta_time()
	_bot_wait[ch] = wait
	if wait > 0.0:
		return false
	var target := mg.nearest(ch)
	var ok := false
	match held[ch]:
		"bomb", "shuriken":
			if target:
				var d := target.global_position - ch.global_position
				d.y = 0.0
				ok = d.length() < 5.5 and d.normalized().dot(ch.facing) > 0.85
		"fire":
			ok = target != null and target.global_position.distance_to(ch.global_position) < FIRE_RADIUS - 0.4
		"ice":
			ok = target != null and target.global_position.distance_to(ch.global_position) < ICE_RADIUS - 0.5
		_:
			ok = true
	if ok:
		_bot_wait.erase(ch)
	return ok
