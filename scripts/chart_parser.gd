class_name ChartParser
## Lee archivos .chart (formato Clone Hero) y carga el audio de una carpeta de canción.

static func load_song(dir: String, difficulty := "ExpertSingle") -> Dictionary:
	var path := dir + "/notes.chart"
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data := parse(text, difficulty)
	data["audio"] = load_audio(dir)
	data["info"] = read_info(dir)
	return data


static func parse(text: String, difficulty: String) -> Dictionary:
	var sections := {}
	var cur := ""
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line == "{" or line == "}":
			continue
		if line.begins_with("[") and line.ends_with("]"):
			cur = line.substr(1, line.length() - 2)
			sections[cur] = []
		elif cur != "":
			sections[cur].append(line)

	var resolution := 192
	var offset := 0.0
	for l in sections.get("Song", []):
		var kv := _kv(l)
		if kv[0] == "Resolution":
			resolution = int(kv[1])
		elif kv[0] == "Offset":
			offset = float(kv[1])

	# Mapa de tempos: [{tick, bpm, time}]
	var tempos: Array = []
	for l in sections.get("SyncTrack", []):
		var kv := _kv(l)
		var parts: PackedStringArray = kv[1].split(" ")
		if parts.size() >= 2 and parts[0] == "B":
			tempos.append({"tick": int(kv[0]), "bpm": float(parts[1]) / 1000.0, "time": 0.0})
	tempos.sort_custom(func(a, b): return a.tick < b.tick)
	if tempos.is_empty():
		tempos.append({"tick": 0, "bpm": 120.0, "time": 0.0})
	for i in range(1, tempos.size()):
		var prev = tempos[i - 1]
		tempos[i].time = prev.time + float(tempos[i].tick - prev.tick) / resolution * 60.0 / prev.bpm

	var notes: Array = []
	for l in sections.get(difficulty, []):
		var kv := _kv(l)
		var parts: PackedStringArray = kv[1].split(" ")
		if parts.size() >= 2 and parts[0] == "N":
			var lane := int(parts[1])
			if lane >= 0 and lane <= 4:  # 5 y 6 (force/open) se ignoran en el prototipo
				notes.append({"t": _tick_to_sec(int(kv[0]), tempos, resolution) + offset, "lane": lane, "hit": false})
	notes.sort_custom(func(a, b): return a.t < b.t)
	return {"notes": notes}


static func _tick_to_sec(tick: int, tempos: Array, resolution: int) -> float:
	var seg = tempos[0]
	for tp in tempos:
		if tp.tick <= tick:
			seg = tp
		else:
			break
	return seg.time + float(tick - seg.tick) / resolution * 60.0 / seg.bpm


static func _kv(line: String) -> Array:
	var i := line.find("=")
	if i < 0:
		return [line, ""]
	return [line.substr(0, i).strip_edges(), line.substr(i + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")]


static func read_info(dir: String) -> Dictionary:
	var info := {"name": dir.get_file(), "artist": ""}
	var p := dir + "/song.ini"
	if FileAccess.file_exists(p):
		for l in FileAccess.get_file_as_string(p).split("\n"):
			var kv := _kv(l.strip_edges())
			if kv[0].to_lower() == "name":
				info["name"] = kv[1]
			elif kv[0].to_lower() == "artist":
				info["artist"] = kv[1]
	return info


static func load_audio(dir: String):
	for f in ["song.ogg", "guitar.ogg", "song.mp3"]:
		var p: String = dir + "/" + f
		if FileAccess.file_exists(p):
			if p.ends_with(".ogg"):
				return AudioStreamOggVorbis.load_from_file(p)
			var s := AudioStreamMP3.new()
			s.data = FileAccess.get_file_as_bytes(p)
			return s
	return null
