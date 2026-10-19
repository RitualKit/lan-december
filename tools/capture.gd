extends Node
## Renders screenshots for visual review (needs a display; use xvfb-run on servers).
##   GAME=res://minigames/x.gd  N=4  TIMES=3,8  OUT=/path/prefix  -> minigame with CPUs
##   GAME=match  N=4  TIMES=1,6,...                                -> full match flow from main.tscn
##   HUMAN=1 adds an idle human so intro/results cards stay up until their timeout.
##   GAME=lobby  N=4                                               -> lobby with CPUs joined

func _ready() -> void:
	var game := OS.get_environment("GAME")
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 4
	var times := Array(OS.get_environment("TIMES").split(",")).map(func(t): return float(t))
	var out := OS.get_environment("OUT")
	Game.players.clear()
	for i in n:
		Game.add_player("", true)
	if OS.get_environment("HUMAN") != "":
		Game.add_player("kb9") # A human who never presses anything: menus wait for timeouts.
	if game == "match" or game == "lobby" or game == "podium":
		var main: Node = load("res://main/main.tscn").instantiate()
		add_child(main)
		if game == "match":
			Game.start_match()
		elif game == "podium":
			for p in Game.players:
				p.score = randi() % 60
			main.goto_podium()
	else:
		var mg: Minigame = load(game).new()
		add_child(mg)
		mg.setup(Game.players)
		mg.begin()
	var t := 0.0
	for i in times.size():
		while t < times[i]:
			await get_tree().process_frame
			t += get_process_delta_time()
		await RenderingServer.frame_post_draw
		var path := "%s_%02d.png" % [out, i]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()
