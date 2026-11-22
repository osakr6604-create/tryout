extends SceneTree
## Writes QR codes for a few reference links as PNG files and prints a
## fingerprint of each, so the encoder can be checked with an independent
## decoder and then pinned by the tests.
##
##   godot --headless --path . --script res://dev/qr_dump.gd -- --out=out/qr

const SAMPLES: Array[String] = [
	"https://example.org/card/#1.ACE.7412.2.0.87.90.66.71.55.80",
	"https://osakr6604-create.github.io/tryout/card/#1.ROOKIE-417.10000.0.6.99.99.99.99.99.99",
	"TRYOUT",
	"https://osakr6604-create.github.io/tryout/card/#1.A_B-C_D-E9.512.5.3.4.0.12.33.7.61 and some padding to reach a larger version of the code, past one hundred and thirty bytes",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out := "out/qr"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	for i in SAMPLES.size():
		var modules := QR.encode(SAMPLES[i])
		var n := modules.size()
		var scale := 8
		var quiet := 4
		var img := Image.create((n + quiet * 2) * scale, (n + quiet * 2) * scale, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		var flat := ""
		for y in n:
			var row: PackedByteArray = modules[y]
			for x in n:
				flat += "1" if row[x] != 0 else "0"
				if row[x] != 0:
					img.fill_rect(Rect2i((x + quiet) * scale, (y + quiet) * scale, scale, scale), Color.BLACK)
		img.save_png("%s/qr_%d.png" % [out, i])
		print("sample %d  size %d  version %d  sha256 %s" % [i, n, (n - 17) / 4, flat.sha256_text()])
	quit(0)
