extends Node2D
## The whole game as one loop:
##
##   attract -> briefing -> (command card -> drill -> result stamp) x 8
##           -> tag entry -> scouting report -> attract
##
## Every state has a way out that needs no input, so a booth machine always
## finds its way back to the attract screen on its own.

enum State { ATTRACT, BRIEFING, CARD, PLAY, FLASH, TAG, REPORT }

const SCREEN := Vector2(1920.0, 1080.0)
const STATE_NAMES: Array[String] = ["attract", "briefing", "card", "play", "flash", "tag", "report"]

var state: State = State.ATTRACT
var state_t: float = 0.0
var session: Session
var model: DrillModel
var view: DrillView
var bot: DrillBot                 ## set when the bot is playing instead of a person
var pointer: Vector2 = SCREEN * 0.5
var idle: float = 0.0
var runs_finished: int = 0

var backdrop: Backdrop
var stage: Node2D
var fx: Fx
var hud: Hud
var attract: Attract
var card: CommandCard
var tag_entry: TagEntry
var report: Report
var operator: OperatorMenu
var crosshair: Crosshair
var board_window: Window

# Launch flags used by the tests, the soak run and the capture tools.
var _autoplay: bool = false
var _skill: float = 0.75
var _forced_seed: int = -1
var _shot_dir: String = ""
var _shot_every: float = 1.0
var _shot_in: float = 0.0
var _shot_count: int = 0
var _quit_after: float = -1.0
var _quit_after_runs: int = -1
var _clock: float = 0.0
var _open_menu_at: float = -1.0
var _soak_log: bool = false

const DEMO_TAGS: Array[String] = [
	"NOVA", "KITE", "ZEPHYR", "MOXIE", "PIXEL", "RIVET", "ECHO", "VANTA", "JUNO", "ORBIT",
	"TALON", "QUILL", "EMBER", "SABLE", "DRIFT", "LYNX", "ONYX", "CINDER", "WREN", "ATLAS",
	"NIMBUS", "RUNE", "VOLT", "COMET", "FROST", "GALE", "MARLO", "TESS", "IKO", "BRAVO7",
]


func _ready() -> void:
	randomize()
	_autoplay = Config.has_flag("autoplay")
	_skill = Config.flag_float("skill", 0.75)
	_forced_seed = Config.flag_int("seed", -1)
	_shot_dir = Config.flag("shots")
	_shot_every = Config.flag_float("shot-every", 1.0)
	_quit_after = Config.flag_float("quit-after", -1.0)
	_quit_after_runs = Config.flag_int("quit-after-runs", -1)
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	_soak_log = Config.has_flag("soak-log")
	if Config.has_flag("menu"):
		_open_menu_at = 0.6
	if Config.has_flag("demo-board"):
		_fill_demo_board(Config.flag_int("demo-board", 12))

	if Config.has_flag("board-only"):
		add_child(BoardScreen.new())
		_apply_display()
		set_process_unhandled_input(false)
		return

	backdrop = Backdrop.new()
	add_child(backdrop)
	stage = Node2D.new()
	add_child(stage)
	fx = Fx.new()
	fx.z_index = 10
	stage.add_child(fx)
	hud = Hud.new()
	hud.visible = false
	add_child(hud)
	attract = Attract.new()
	add_child(attract)
	card = CommandCard.new()
	add_child(card)
	tag_entry = TagEntry.new()
	tag_entry.submitted.connect(_on_tag_submitted)
	add_child(tag_entry)
	report = Report.new()
	add_child(report)
	operator = OperatorMenu.new()
	operator.display_changed.connect(_apply_display)
	operator.quit_requested.connect(func() -> void: get_tree().quit())
	operator.closed.connect(func() -> void: idle = 0.0)
	add_child(operator)
	crosshair = Crosshair.new()
	crosshair.z_index = 100
	add_child(crosshair)

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_apply_display()
	_enter_attract()


## Puts simulated runs on the board, so a demo or a quiet booth shows a full
## leaderboard. The scores are real: each one is a whole run played by the bot.
func _fill_demo_board(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var run := Sim.session(rng.randf_range(0.35, 0.97), 500 + i)
		Board.submit(DEMO_TAGS[i % DEMO_TAGS.size()], run)
	Board.last_entry = {}


func _exit_tree() -> void:
	Look.release()


# ---- display ----

func _apply_display() -> void:
	if OS.has_feature("web"):
		return
	var window := get_window()
	var want_mode := Window.MODE_FULLSCREEN if Config.fullscreen else Window.MODE_WINDOWED
	if window.mode != want_mode:
		window.mode = want_mode
	if Config.low_latency:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 480
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		Engine.max_fps = 0
	_sync_board_window()


## Opens, moves or closes the leaderboard window to match the settings.
func _sync_board_window() -> void:
	if Config.has_flag("board-only"):
		return
	var screens := DisplayServer.get_screen_count()
	var main_screen := get_window().current_screen
	var want := -2
	if Config.has_flag("board"):
		want = main_screen
	elif Config.board_screen == -1:
		for i in screens:
			if i != main_screen:
				want = i
				break
	elif Config.board_screen >= 0 and Config.board_screen < screens:
		want = Config.board_screen
	if want == -2:
		if board_window != null:
			board_window.queue_free()
			board_window = null
		return
	if board_window == null:
		board_window = Window.new()
		board_window.title = "Tryout leaderboard"
		board_window.content_scale_size = Vector2i(1920, 1080)
		board_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		board_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		board_window.size = Vector2i(960, 540)
		board_window.add_child(BoardScreen.new())
		board_window.close_requested.connect(_on_board_window_closed)
		add_child(board_window)
	board_window.current_screen = want
	board_window.mode = Window.MODE_WINDOWED if want == main_screen else Window.MODE_FULLSCREEN


func _on_board_window_closed() -> void:
	Config.board_screen = -2
	Config.save()
	_sync_board_window()


# ---- the loop ----

func _process(delta: float) -> void:
	_clock += delta
	if stage == null:
		_capture(delta)
		return
	state_t += delta
	idle += delta
	stage.position = fx.offset()
	crosshair.position = pointer
	crosshair.visible = state != State.BRIEFING

	if _open_menu_at > 0.0 and _clock >= _open_menu_at:
		_open_menu_at = -1.0
		operator.open()

	if not operator.is_open:
		match state:
			State.ATTRACT:
				if _autoplay and state_t > 1.2:
					_start_run()
			State.BRIEFING:
				if card.finished():
					_next_drill()
			State.CARD:
				if card.finished():
					_begin_play()
			State.PLAY:
				_tick_play(delta)
			State.FLASH:
				if card.finished():
					_after_flash()
			State.TAG:
				if _autoplay and state_t > 1.4:
					_on_tag_submitted("BOT%03d" % (randi() % 1000))
			State.REPORT:
				if report.expired() or (_autoplay and state_t > Report.T_READY + 3.0):
					_leave_report()

		# A player who walks away mid-run must not block the booth.
		if bot == null and idle > Tuning.IDLE_ABORT_SECONDS and state in [State.BRIEFING, State.CARD, State.PLAY, State.FLASH]:
			_abandon()

	_capture(delta)


func _set_state(next: State) -> void:
	state = next
	state_t = 0.0


func _enter_attract() -> void:
	_clear_drill()
	session = null
	bot = null
	hud.visible = false
	card.hide_card()
	tag_entry.close()
	report.close()
	attract.open()
	crosshair.style = &"menu"
	backdrop.set_mood(Look.accent(), 0.0)
	Board.set_live({"state": "idle"})
	Sfx.music(&"music_attract")
	_set_state(State.ATTRACT)


func _start_run() -> void:
	idle = 0.0
	attract.close()
	report.close()
	var seed_value := _forced_seed if _forced_seed >= 0 else int(randi())
	session = Session.create(seed_value)
	hud.set_score(0, true)
	hud.visible = false
	crosshair.style = &"menu"
	backdrop.set_mood(Look.accent(), 0.5)
	Sfx.music(&"music_run")
	Sfx.play(&"start")
	card.show_briefing(Tuning.BRIEFING_SECONDS)
	Board.set_live({"state": "playing", "drill": 0, "title": "GET READY", "score": 0})
	_set_state(State.BRIEFING)


func _next_drill() -> void:
	_clear_drill()
	model = session.next_model(Tuning.FIELD)
	view = DrillView.create(model.id)
	stage.add_child(view)
	stage.move_child(view, 0)
	view.bind(model, fx)
	view.frozen = true
	bot = DrillBot.create(model, _skill, int(randi())) if _autoplay else null
	pointer = pointer.clamp(Vector2.ZERO, SCREEN)
	hud.visible = true
	hud.running = false
	hud.timed = model.timed
	hud.set_drill(session.index, model.title, model.hint)
	hud.seconds_left = model.duration
	hud.fraction_left = 1.0
	crosshair.style = view.crosshair()
	backdrop.set_mood(view.mood(), 1.0)
	card.show_command(session.index, model.title, model.hint, Tuning.CARD_SECONDS)
	Board.set_live({"state": "playing", "drill": session.index, "title": model.title, "score": session.total()})
	_set_state(State.CARD)


func _begin_play() -> void:
	card.hide_card()
	view.frozen = false
	hud.running = true
	model.move(pointer)
	_set_state(State.PLAY)


func _tick_play(delta: float) -> void:
	if bot != null:
		bot.step(delta)
		pointer = bot.cursor
	else:
		model.move(pointer)
	model.advance(delta)
	view.handle(model.take_events())
	hud.seconds_left = model.time_left()
	hud.fraction_left = 1.0 - model.progress()
	hud.live_stat = model.live_stat()
	if model.done:
		_finish_drill()


func _finish_drill() -> void:
	var result := model.result()
	var before := session.total()
	session.record(result)
	hud.set_score(session.total())
	hud.running = false
	card.show_stamp(result, session.total() - before, Tuning.FLASH_SECONDS)
	Board.set_live({"state": "playing", "drill": mini(session.index, Session.drill_count() - 1), "title": model.title, "score": session.total()})
	_set_state(State.FLASH)


func _after_flash() -> void:
	card.hide_card()
	if session.is_complete():
		_enter_tag()
	else:
		_next_drill()


func _enter_tag() -> void:
	_clear_drill()
	hud.visible = false
	crosshair.style = &"menu"
	backdrop.set_mood(Look.accent(), 0.3)
	var place := Board.data.rank_for_score(session.total(), Leaderboard.Scope.TODAY, Board.today())
	tag_entry.open(session.total(), session.grade(), place)
	Sfx.music(&"music_attract")
	_set_state(State.TAG)


func _on_tag_submitted(raw: String) -> void:
	if state != State.TAG:
		return
	var tag := NameFilter.accept(raw)
	if tag == "":
		tag = NameFilter.fallback(int(randi()))
	tag_entry.close()
	var entry := Board.submit(tag, session)
	var place := Board.rank_today(int(entry["id"]))
	report.open(session, entry, place, Board.count_today())
	attract.board.highlight_id = int(entry["id"])
	Board.set_live({"state": "report", "tag": tag, "score": session.total()})
	runs_finished += 1
	if _soak_log:
		print("soak run=%d score=%d nodes=%d objects=%d orphans=%d static_mb=%.2f" % [
			runs_finished, session.total(),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		])
	_set_state(State.REPORT)


func _leave_report() -> void:
	if _quit_after_runs > 0 and runs_finished >= _quit_after_runs:
		get_tree().quit()
		return
	if _autoplay:
		_start_run()
	else:
		_enter_attract()


func _abandon() -> void:
	Sfx.play(&"miss")
	_enter_attract()


func _clear_drill() -> void:
	if view != null:
		view.queue_free()
		view = null
	model = null
	if fx != null:
		fx.clear()


# ---- input ----

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = (event as InputEventMouseMotion).position
		idle = 0.0
		if operator.is_open:
			operator.hover(pointer)
		elif state == State.TAG:
			tag_entry.hover(pointer)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			pointer = click.position
			idle = 0.0
			crosshair.press()
			_press(pointer)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			idle = 0.0
			_key(key)


func _press(pos: Vector2) -> void:
	if operator.is_open:
		operator.press(pos)
		return
	match state:
		State.ATTRACT:
			_start_run()
		State.PLAY:
			if bot == null and view != null:
				view.pointer_pressed(pos)
		State.TAG:
			tag_entry.press(pos)
		State.REPORT:
			if report.ready_for_next():
				report.close()
				_start_run()


func _key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_F1, KEY_ESCAPE:
			if operator.is_open:
				operator.close()
			else:
				# The menu is for staff between players; opening it ends any run in progress.
				if state != State.ATTRACT and state != State.REPORT:
					_enter_attract()
				operator.open()
			return
		KEY_F11:
			Config.fullscreen = not Config.fullscreen
			_apply_display()
			return
	if operator.is_open:
		return
	match state:
		State.ATTRACT:
			if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_start_run()
		State.TAG:
			tag_entry.key(key)
		State.REPORT:
			if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and report.ready_for_next():
				report.close()
				_start_run()


# ---- capture and timed exit, for the tools ----

func _capture(delta: float) -> void:
	if _quit_after > 0.0 and _clock >= _quit_after:
		get_tree().quit()
		return
	if _shot_dir == "":
		return
	_shot_in -= delta
	if _shot_in > 0.0:
		return
	_shot_in = _shot_every
	var label := STATE_NAMES[state] if stage != null else "board"
	if model != null:
		label += "_" + String(model.id)
	var path := "%s/%03d_%s.png" % [_shot_dir, _shot_count, label]
	_shot_count += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
