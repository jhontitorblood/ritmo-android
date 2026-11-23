extends Node
## Menús, selección de canciones, modo historia con videos y resultados.

const SONG_ROOTS := ["user://songs", "res://songs", "/storage/emulated/0/RitmoSongs"]
const DIFFICULTIES := {"Fácil": "EasySingle", "Medio": "MediumSingle", "Difícil": "HardSingle", "Experto": "ExpertSingle"}
const SAVE_PATH := "user://progress.json"

var ui: Control
var difficulty := "ExpertSingle"
var story := {"zones": []}
var progress := {"zone": 0, "song": 0}


func _ready() -> void:
	OS.request_permissions()
	_load_story()
	_load_progress()
	show_menu()


# ---------- Utilidades de UI ----------

func _reset_ui() -> VBoxContainer:
	if ui:
		ui.queue_free()
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	var bg := ColorRect.new()
	bg.color = Color("0b0b14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	return box


func _title(box: Control, text: String, size := 48) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)


func _button(box: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 70)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


# ---------- Menú principal ----------

func show_menu() -> void:
	var box := _reset_ui()
	_title(box, "RITMO", 96)
	_button(box, "Modo Historia", show_story)
	_button(box, "Toque Rápido", show_songs)
	_button(box, "Salir", func(): get_tree().quit())


# ---------- Canciones ----------

func find_songs() -> Array:
	var out: Array = []
	for root in SONG_ROOTS:
		var d := DirAccess.open(root)
		if d == null:
			continue
		for name in d.get_directories():
			var dir: String = root + "/" + name
			if FileAccess.file_exists(dir + "/notes.chart"):
				out.append(dir)
	return out


func resolve_song(name: String) -> String:
	for root in SONG_ROOTS:
		var dir: String = root + "/" + name
		if FileAccess.file_exists(dir + "/notes.chart"):
			return dir
	return ""


func show_songs() -> void:
	var box := _reset_ui()
	_title(box, "Elige una canción")

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(420, 60)
	var idx := 0
	var i := 0
	for k in DIFFICULTIES:
		opt.add_item(k)
		if DIFFICULTIES[k] == difficulty:
			idx = i
		i += 1
	opt.select(idx)
	opt.item_selected.connect(func(n): difficulty = DIFFICULTIES[opt.get_item_text(n)])
	box.add_child(opt)

	var songs := find_songs()
	if songs.is_empty():
		var l := Label.new()
		l.text = "No hay canciones.\nColoca carpetas con notes.chart, song.ini y song.ogg en:\n%s/songs\no /storage/emulated/0/RitmoSongs" % OS.get_user_data_dir()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(520, 380)
		var list := VBoxContainer.new()
		scroll.add_child(list)
		box.add_child(scroll)
		for dir in songs:
			var info := ChartParser.read_info(dir)
			var label: String = info.name if info.artist == "" else "%s — %s" % [info.name, info.artist]
			var b := Button.new()
			b.text = label
			b.custom_minimum_size = Vector2(500, 64)
			b.add_theme_font_size_override("font_size", 24)
			b.pressed.connect(func(): play_song(dir, show_songs))
			list.add_child(b)
	_button(box, "Volver", show_menu)


# ---------- Jugar ----------

func play_song(dir: String, back: Callable, on_result: Callable = Callable()) -> void:
	var data := ChartParser.load_song(dir, difficulty)
	if data.is_empty() or data.notes.is_empty():
		var box := _reset_ui()
		_title(box, "No se pudo cargar la canción\n(¿falta la dificultad %s?)" % difficulty, 32)
		_button(box, "Volver", back)
		return
	if ui:
		ui.queue_free()
	var game := Control.new()
	game.set_script(load("res://scripts/game.gd"))
	game.setup(data)
	ui = game
	add_child(game)
	game.finished.connect(func(result: Dictionary):
		if result.aborted:
			back.call()
		elif on_result.is_valid():
			on_result.call(result)
		else:
			show_result(result, dir, back))


func show_result(r: Dictionary, dir: String, back: Callable) -> void:
	var box := _reset_ui()
	_title(box, "Resultado", 64)
	_title(box, "%s\nPuntos: %d\nNotas: %d / %d\nMejor racha: %d" % ["★".repeat(r.stars) + "☆".repeat(5 - r.stars), r.score, r.hits, r.total, r.best_combo], 36)
	_button(box, "Reintentar", func(): play_song(dir, back))
	_button(box, "Continuar", back)


# ---------- Modo historia ----------

func _load_story() -> void:
	for p in ["user://story.json", "res://story/story.json"]:
		if FileAccess.file_exists(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary:
				story = parsed
				return


func _load_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary:
			progress = {"zone": int(parsed.get("zone", 0)), "song": int(parsed.get("song", 0))}


func _save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(progress))


func show_story() -> void:
	var box := _reset_ui()
	var zones: Array = story.get("zones", [])
	_title(box, "Modo Historia", 64)
	if zones.is_empty():
		_title(box, "No hay historia definida.\nCrea story/story.json (ver README).", 28)
		_button(box, "Volver", show_menu)
		return
	if progress.zone >= zones.size():
		_title(box, "¡Historia completada!", 40)
		_button(box, "Reiniciar historia", func():
			progress = {"zone": 0, "song": 0}
			_save_progress()
			show_story())
		_button(box, "Volver", show_menu)
		return
	var z: Dictionary = zones[progress.zone]
	var zsongs: Array = z.get("songs", [])
	_title(box, "Zona %d: %s" % [progress.zone + 1, z.get("name", "")], 40)
	_title(box, "Canción %d de %d" % [progress.song + 1, zsongs.size()], 28)
	_button(box, "Jugar", _play_story_song)
	_button(box, "Volver", show_menu)


func _play_story_song() -> void:
	var z: Dictionary = story.zones[progress.zone]
	var name: String = z.songs[progress.song]
	var dir := resolve_song(name)
	if dir == "":
		var box := _reset_ui()
		_title(box, "Falta la canción \"%s\"\nen las carpetas de canciones." % name, 32)
		_button(box, "Volver", show_story)
		return
	play_song(dir, show_story, _on_story_result)


func _on_story_result(r: Dictionary) -> void:
	var z: Dictionary = story.zones[progress.zone]
	var min_stars := int(z.get("min_stars", 2))
	var box := _reset_ui()
	_title(box, "%s\n%d puntos" % ["★".repeat(r.stars) + "☆".repeat(5 - r.stars), r.score], 48)
	if r.stars < min_stars:
		_title(box, "Necesitas %d estrellas para avanzar." % min_stars, 30)
		_button(box, "Reintentar", _play_story_song)
		_button(box, "Volver", show_story)
		return
	progress.song += 1
	if progress.song >= z.songs.size():
		progress.song = 0
		progress.zone += 1
		_save_progress()
		_title(box, "¡Zona completada!", 40)
		_button(box, "Continuar", func(): _play_video(z.get("video", ""), show_story))
	else:
		_save_progress()
		_button(box, "Siguiente canción", show_story)


func _play_video(path: String, then: Callable) -> void:
	# Godot reproduce de forma nativa solo video Ogg Theora (.ogv)
	if path == "" or not FileAccess.file_exists(path):
		then.call()
		return
	var box := _reset_ui()
	var vp := VideoStreamPlayer.new()
	var stream := VideoStreamTheora.new()
	stream.file = path
	vp.stream = stream
	vp.expand = true
	vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(vp)
	var skip := Button.new()
	skip.text = "Saltar"
	skip.custom_minimum_size = Vector2(160, 60)
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.position = Vector2(-180, -80)
	ui.add_child(skip)
	var done := func():
		if is_instance_valid(vp):
			vp.stop()
		then.call()
	vp.finished.connect(done, CONNECT_ONE_SHOT)
	skip.pressed.connect(done, CONNECT_ONE_SHOT)
	vp.play()
