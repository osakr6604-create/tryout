extends Node
## Booth settings. Autoloaded as "Config".
##
## Defaults live here. A booth can override them without rebuilding by placing
## a booth.cfg next to the executable (see booth.example.cfg); changes made in
## the operator menu are saved to user://booth.cfg. Launch flags after "--"
## win over both, which is what the tests and the capture tools use.

const USER_FILE := "user://booth.cfg"
const LOCAL_FILE := "booth.cfg"

var event_name: String = ""            ## shown on the attract screen and the board
var idle_seconds: float = 25.0         ## report screen returns to attract after this
var kiosk: bool = false                ## hides Quit in the operator menu
var fullscreen: bool = true
var low_latency: bool = false          ## V-Sync off and a high frame cap, for tighter timing
var board_screen: int = -1             ## -1 second screen if there is one, -2 never, else a screen index
var master_volume: float = 0.9
var music_volume: float = 0.5
var card_url: String = "https://osakr6604-create.github.io/tryout/card/"
var show_qr: bool = true
var accent: Color = Color("2EC5FF")
var logo_path: String = ""             ## optional PNG or JPG next to the executable
var logo: Texture2D                    ## the loaded logo, or null

var flags: Dictionary = {}             ## launch flags, e.g. {"windowed": "true", "seed": "7"}


func _ready() -> void:
	_read(USER_FILE)
	if not OS.has_feature("web") and not OS.has_feature("editor"):
		_read(OS.get_executable_path().get_base_dir().path_join(LOCAL_FILE))
	_parse_flags()
	if has_flag("logo"):
		logo_path = flag("logo")
	_load_logo()
	if has_flag("windowed"):
		fullscreen = false
	if has_flag("mute"):
		master_volume = 0.0


## The event's own logo, shown in a corner of the attract and leaderboard
## screens. A file name is looked up next to the executable.
func _load_logo() -> void:
	logo = null
	if logo_path == "":
		return
	var path := logo_path
	if path.is_relative_path() and not path.begins_with("res://"):
		path = OS.get_executable_path().get_base_dir().path_join(path)
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("The logo could not be loaded: %s" % path)
		return
	logo = ImageTexture.create_from_image(image)


func _parse_flags() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			flags[body] = "true"
		else:
			flags[body.substr(0, eq)] = body.substr(eq + 1)
	# In a browser the same flags come from the address, e.g. ?autoplay&skill=0.8
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for part in query.trim_prefix("?").split("&", false):
			var eq := part.find("=")
			if eq < 0:
				flags[part.uri_decode()] = "true"
			else:
				flags[part.substr(0, eq).uri_decode()] = part.substr(eq + 1).uri_decode()


func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)


func flag(flag_name: String, fallback: String = "") -> String:
	return str(flags.get(flag_name, fallback))


func flag_float(flag_name: String, fallback: float) -> float:
	return float(flags[flag_name]) if flags.has(flag_name) else fallback


func flag_int(flag_name: String, fallback: int) -> int:
	return int(flags[flag_name]) if flags.has(flag_name) else fallback


func _read(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	event_name = str(file.get_value("booth", "event_name", event_name))
	idle_seconds = clampf(float(file.get_value("booth", "idle_seconds", idle_seconds)), 8.0, 300.0)
	kiosk = bool(file.get_value("booth", "kiosk", kiosk))
	card_url = str(file.get_value("booth", "card_url", card_url))
	show_qr = bool(file.get_value("booth", "show_qr", show_qr))
	logo_path = str(file.get_value("booth", "logo", logo_path))
	fullscreen = bool(file.get_value("display", "fullscreen", fullscreen))
	low_latency = bool(file.get_value("display", "low_latency", low_latency))
	board_screen = int(file.get_value("display", "board_screen", board_screen))
	master_volume = clampf(float(file.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(file.get_value("audio", "music", music_volume)), 0.0, 1.0)
	var accent_text := str(file.get_value("theme", "accent", ""))
	if Color.html_is_valid(accent_text):
		accent = Color.html(accent_text)


## Saves what the operator menu can change.
func save() -> void:
	var file := ConfigFile.new()
	file.load(USER_FILE)
	file.set_value("booth", "event_name", event_name)
	file.set_value("booth", "idle_seconds", idle_seconds)
	file.set_value("booth", "kiosk", kiosk)
	file.set_value("booth", "card_url", card_url)
	file.set_value("booth", "show_qr", show_qr)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("display", "low_latency", low_latency)
	file.set_value("display", "board_screen", board_screen)
	file.set_value("audio", "master", master_volume)
	file.set_value("audio", "music", music_volume)
	file.save(USER_FILE)
