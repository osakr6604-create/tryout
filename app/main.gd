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
const WINDOWED_SIZE := Vector2i(1280, 720)
const MAX_DEMO_ENTRIES := 200     ## each one is a whole simulated run, so the flag is capped
const STATE_NAMES: Array[String] = ["attract", "briefing", "card", "play", "flash", "tag", "report"]

var state: State = State.ATTRACT
var state_t: float = 0.0
var session: Session
var model: DrillModel
var view: DrillView
var bot: DrillBot                 ## set when the bot is playing instead of a person
var pointer: Vector2 = Vector2(840.0, 800.0)   ## until the mouse moves: beside the start button
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
var _through_input: bool = false    ## the demo player sends real mouse events instead of calling the drill
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
var _menu_test_step: int = -1
var _menu_test_t: float = 0.0
var _click_sent: bool = false
var _window_placed: bool = false
var _soak_log: bool = false
var _attract_hold: float = 1.2
var _report_hold: float = Report.T_READY + 3.0
var _typed_tag: String = ""
var _type_in: float = 0.0
var _event_log: FileAccess
var _board_seq_dir: String = ""
var _board_seq_count: int = 0

const DEMO_TAGS: Array[String] = [
	"NOVA", "KITE", "ZEPHYR", "MOXIE", "PIXEL", "RIVET", "ECHO", "VANTA", "JUNO", "ORBIT",
	"TALON", "QUILL", "EMBER", "SABLE", "DRIFT", "LYNX", "ONYX", "CINDER", "WREN", "ATLAS",
	"NIMBUS", "RUNE", "VOLT", "COMET", "FROST", "GALE", "MARLO", "TESS", "IKO", "BRAVO7",
]


func _ready() -> void:
	randomize()
	_through_input = Config.has_flag("autoplay-input")
	_autoplay = Config.has_flag("autoplay") or _through_input
	_skill = Config.flag_float("skill", 0.75)
	_forced_seed = Config.flag_int("seed", -1)
	# The capture flags write files, so they only apply to a desktop build.
	# In a browser the flags come from the address bar and anyone can type one.
	var desktop := not OS.has_feature("web")
	_shot_dir = Config.flag("shots") if desktop else ""
	_shot_every = Config.flag_float("shot-every", 1.0)
	_quit_after = Config.flag_float("quit-after", -1.0)
	_quit_after_runs = Config.flag_int("quit-after-runs", -1)
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	_soak_log = Config.has_flag("soak-log")
	_attract_hold = Config.flag_float("attract-hold", 1.2)
	_report_hold = Config.flag_float("report-hold", Report.T_READY + 3.0)
	_typed_tag = Config.flag("tag")
	_board_seq_dir = Config.flag("board-seq") if desktop else ""
	if _board_seq_dir != "":
		DirAccess.make_dir_recursive_absolute(_board_seq_dir)
	if desktop and Config.has_flag("event-log"):
		_event_log = FileAccess.open(Config.flag("event-log"), FileAccess.WRITE)
	if Config.has_flag("menu") or Config.has_flag("menu-test"):
		_open_menu_at = 0.6
	if Config.has_flag("menu-test"):
		_menu_test_step = 0
	if Config.has_flag("demo-board"):
		_fill_demo_board(clampi(Config.flag_int("demo-board", 12), 0, MAX_DEMO_ENTRIES))

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
	if Config.has_flag("offscreen"):
		# Recording: a full-size borderless window parked beside the desktop,
		# so a capture never covers what the person at the PC is doing.
		window.mode = Window.MODE_WINDOWED
		window.borderless = true
		window.size = Vector2i(1920, 1080)
		window.position = Vector2i(DisplayServer.screen_get_size().x + 80, 0)
		_sync_board_window()
		return
	var want_mode := Window.MODE_FULLSCREEN if Config.fullscreen else Window.MODE_WINDOWED
	if window.mode != want_mode or not _window_placed:
		window.mode = want_mode
		if want_mode == Window.MODE_WINDOWED:
			# A window two thirds the size of the frame, centred on its screen.
			var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
			window.size = WINDOWED_SIZE
			window.position = screen.position + (screen.size - WINDOWED_SIZE) / 2
		_window_placed = true
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
	if Config.has_flag("offscreen"):
		board_window.borderless = true
		board_window.size = Vector2i(960, 540)
		board_window.position = Vector2i(DisplayServer.screen_get_size().x + 80, 1200)


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

	if _menu_test_step >= 0:
		_menu_test(delta)

	if not operator.is_open:
		match state:
			State.ATTRACT:
				if _autoplay and state_t > _attract_hold:
					if _through_input:
						if not _click_sent:
							_click_sent = true
							_send_click(Attract.START_RECT.get_center())
					else:
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
				if _autoplay:
					_autoplay_tag(delta)
			State.REPORT:
				if _through_input and state_t > _report_hold and not _click_sent and not _last_run():
					_click_sent = true
					_send_click(Report.NEXT_RECT.get_center())
				elif report.expired() or (_autoplay and state_t > _report_hold and (not _through_input or _last_run())):
					_leave_report()

		# A player who walks away mid-run must not block the booth.
		if bot == null and idle > Tuning.IDLE_ABORT_SECONDS and state in [State.BRIEFING, State.CARD, State.PLAY, State.FLASH]:
			_abandon()

	_capture(delta)


func _set_state(next: State) -> void:
	state = next
	state_t = 0.0
	_click_sent = false
	_log_event({"state": STATE_NAMES[next]})


func _last_run() -> bool:
	return _quit_after_runs > 0 and runs_finished >= _quit_after_runs


## A real mouse move, sent through the engine's input system. The position is
## given in the game's 1920 x 1080 frame and converted to window pixels, the
## same units the operating system reports.
func _send_motion(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = get_viewport().get_final_transform() * pos
	event.global_position = event.position
	Input.parse_input_event(event)


## A real left click: button down, then up.
func _send_click(pos: Vector2) -> void:
	_send_motion(pos)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = get_viewport().get_final_transform() * pos
		event.global_position = event.position
		Input.parse_input_event(event)


## Writes one line to the event log when a capture asked for one. The video
## tools use it to place captions on the exact frame something happened.
func _log_event(data: Dictionary) -> void:
	if _event_log == null:
		return
	data["t"] = snappedf(_clock, 0.001)
	if model != null:
		data["drill"] = String(model.id)
	_event_log.store_line(JSON.stringify(data))
	_event_log.flush()


## With the demo player at the controls, the tag is typed a key at a time the
## way a person would, or a numbered one is used when none was given.
func _autoplay_tag(delta: float) -> void:
	if _through_input:
		_autoplay_tag_by_mouse(delta)
		return
	if _typed_tag == "":
		if state_t > 1.4:
			_on_tag_submitted("BOT%03d" % (randi() % 1000))
		return
	if state_t < 1.0:
		return
	_type_in -= delta
	if _type_in > 0.0:
		return
	_type_in = 0.2
	if tag_entry.text.length() < _typed_tag.length():
		var event := InputEventKey.new()
		event.keycode = KEY_UNKNOWN
		event.unicode = _typed_tag.unicode_at(tag_entry.text.length())
		event.pressed = true
		tag_entry.key(event)
	else:
		_type_in = 99.0
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.pressed = true
		tag_entry.key(enter)


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
	bot = null
	if _autoplay:
		# With a fixed seed the demo player repeats exactly, so a take can be re-recorded.
		var bot_seed := hash([_forced_seed, session.index, "bot"]) if _forced_seed >= 0 else int(randi())
		bot = DrillBot.create(model, _skill, bot_seed)
		if _through_input:
			bot.move_through = _send_motion
			bot.press_through = _send_click
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
	if bot != null and not _through_input:
		bot.step(delta)
		pointer = bot.cursor
	else:
		if bot != null:
			bot.step(delta)    # its moves and clicks arrive below as mouse events
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
	_log_event({"result": result.stamp(), "score": snappedf(result.score, 0.1), "headline": result.headline, "total": session.total()})
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
	_type_in = 0.0
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
	_log_event({"report": tag, "total": session.total(), "grade": session.grade(), "role": session.role(), "place": place})
	if _soak_log:
		print("soak run=%d score=%d nodes=%d objects=%d orphans=%d static_mb=%.2f texture_mb=%.2f process_mb=%.1f" % [
			runs_finished, session.total(),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			float(OS.get_static_memory_peak_usage()) / 1048576.0,
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


## A check for the tools: works the booth menu with real mouse clicks (export,
## clear today with its second click, a volume step, back) and prints what
## happened, so the menu's click path is covered without a person.
func _menu_test(delta: float) -> void:
	const PLAN: Array = [[0.5, "export"], [1.0, "reset_today"], [1.5, "reset_today"], [2.0, "music"], [2.5, "resume"]]
	if not operator.is_open and _menu_test_step == 0:
		return   # not opened yet
	_menu_test_t += delta
	if _menu_test_step < PLAN.size():
		if _menu_test_t >= float(PLAN[_menu_test_step][0]):
			_send_click(operator.button_rect(str(PLAN[_menu_test_step][1])).get_center())
			_menu_test_step += 1
	elif _menu_test_t >= 3.2:
		print("menu-test exported=%s today=%d music=%.2f open=%s" % [
			str(operator.last_export != "" and FileAccess.file_exists(operator.last_export)),
			Board.count_today(), Config.music_volume, str(operator.is_open),
		])
		_menu_test_step = -1


## The same, but by clicking the on-screen keys with real mouse events.
func _autoplay_tag_by_mouse(delta: float) -> void:
	if state_t < 1.0:
		return
	_type_in -= delta
	if _type_in > 0.0:
		return
	_type_in = 0.25
	var want := _typed_tag if _typed_tag != "" else "MOUSE7"
	var next := "done" if tag_entry.text.length() >= want.length() else want[tag_entry.text.length()]
	var rect := tag_entry.key_rect(next)
	if rect.size.x > 0.0:
		_send_click(rect.get_center())
	if next == "done":
		_type_in = 99.0


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
			if (bot == null or _through_input) and view != null:
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
	# Every other frame of the leaderboard window, for the two-screen shots in the video.
	if _board_seq_dir != "" and board_window != null and Engine.get_frames_drawn() % 2 == 0:
		var frame := "%s/b_%05d.png" % [_board_seq_dir, _board_seq_count]
		_board_seq_count += 1
		board_window.get_texture().get_image().save_png(frame)
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
