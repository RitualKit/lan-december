class_name PlayerSlot
extends RefCounted
## One participant in the match: a human on a device, or a CPU.

var id := 0 ## Colour index, 0..7. Stable for the whole session.
var character := 0 ## Index into Art.CHARACTERS.
var device := "" ## Controls device ("kb0", "pad1", ...), "net" for a remote player, "" for CPUs.
var owner := "" ## Online: the page (room peer) whose player this is; "" offline and for CPUs.
var is_bot := false
var skill := 0.75 ## CPU only: 0 = sleepy, 1 = sharp.
var score := 0
var last_points := 0
var round_wins := 0


func _init(p_id: int, p_device: String, p_bot := false) -> void:
	id = p_id
	character = p_id
	device = p_device
	is_bot = p_bot


var color: Color:
	get:
		return Art.PLAYER_COLORS[id % Art.PLAYER_COLORS.size()]

var display_name: String:
	get:
		return ("CPU %d" if is_bot else "P%d") % (id + 1)
