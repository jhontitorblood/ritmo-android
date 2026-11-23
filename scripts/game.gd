extends Control
## Pantalla de juego: highway en pseudo-3D, 5 trastes táctiles, puntuación y racha.

signal finished(result: Dictionary)

const COLORS := [Color("2ecc40"), Color("ff4136"), Color("ffdc00"), Color("0074d9"), Color("ff851b")]
const KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G]  # para probar en PC
const LEAD_IN := 2.0

var song: Dictionary = {}
var notes: Array = []
var player := AudioStreamPlayer.new()

var clock := -LEAD_IN
var started := false
var paused := false
var lookahead := 1.6          # segundos visibles (velocidad del highway)
var hit_window := 0.12        # segundos de tolerancia
var audio_delay := 0.0        # calibración manual (segundos)

var score := 0
var combo := 0
var best_combo := 0
var hits := 0
var misses := 0
var next_idx := 0
var held := {}                # índice de dedo -> carril
var lane_lit := [false, false, false, false, false]
var end_time := 0.0


func setup(s: Dictionary) -> void:
	song = s
	notes = s.get("notes", [])
	end_time = (notes.back().t if notes.size() > 0 else 0.0) + 2.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(player)
	if song.get("audio") != null:
		player.stream = song["audio"]


func _process(delta: float) -> void:
	if paused:
		return
	if clock < 0.0:
		clock += delta
		if clock >= 0.0 and player.stream != null:
			player.play()
			started = true
	elif player.playing:
		clock = player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() + audio_delay
	else:
		clock += delta

	# Notas perdidas
	while next_idx < notes.size() and notes[next_idx].t < clock - hit_window:
		if not notes[next_idx].hit:
			misses += 1
			combo = 0
		next_idx += 1

	if clock > end_time:
		_finish(false)
	queue_redraw()


func _multiplier() -> int:
	return mini(1 + combo / 10, 4)


func _press_lane(lane: int) -> void:
	lane_lit[lane] = true
	var i := next_idx
	while i < notes.size() and notes[i].t <= clock + hit_window:
		var n = notes[i]
		if not n.hit and n.lane == lane and absf(n.t - clock) <= hit_window:
			n.hit = true
			hits += 1
			combo += 1
			best_combo = maxi(best_combo, combo)
			score += 50 * _multiplier()
			return
		i += 1
	# Toque sin nota: sin penalización (más cómodo en pantalla táctil)


func _release_lane(lane: int) -> void:
	lane_lit[lane] = false


func _geometry() -> Dictionary:
	var lane_w := minf(size.x * 0.11, 120.0)
	return {
		"lane_w": lane_w,
		"cx": size.x * 0.5,
		"hit_y": size.y * 0.78,
		"top_y": size.y * 0.08,
	}


func _lane_at(pos: Vector2) -> int:
	var g := _geometry()
	var left: float = g.cx - 2.5 * g.lane_w
	return clampi(int((pos.x - left) / g.lane_w), 0, 4)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			if pos.x > size.x - 110.0 and pos.y < 110.0:
				_toggle_pause()
				return
			if paused:
				if _exit_rect().has_point(pos):
					_finish(true)
				return
			if pos.y > size.y * 0.55:
				var lane := _lane_at(pos)
				held[event.index] = lane
				_press_lane(lane)
		else:
			if held.has(event.index):
				_release_lane(held[event.index])
				held.erase(event.index)
	elif event is InputEventKey and not event.echo:
		var idx := KEYS.find(event.keycode)
		if idx >= 0 and not paused:
			if event.pressed:
				_press_lane(idx)
			else:
				_release_lane(idx)


func _toggle_pause() -> void:
	paused = not paused
	player.stream_paused = paused
	queue_redraw()


func _exit_rect() -> Rect2:
	return Rect2(size.x * 0.5 - 140.0, size.y * 0.5 - 40.0, 280.0, 80.0)


func _finish(aborted: bool) -> void:
	set_process(false)
	set_process_input(false)
	player.stop()
	var total := hits + misses
	var ratio := float(hits) / float(maxi(total, 1))
	finished.emit({
		"aborted": aborted,
		"score": score,
		"hits": hits,
		"total": total,
		"best_combo": best_combo,
		"ratio": ratio,
		"stars": clampi(int(ratio * 5.0), 0, 5),
	})


func _project(lane: int, t: float) -> Vector2:
	# t = 0 en la línea de golpe, 1 en el horizonte
	var g := _geometry()
	var depth := pow(t, 0.85)
	var y: float = lerpf(g.hit_y, g.top_y, depth)
	var sc: float = lerpf(1.0, 0.32, depth)
	return Vector2(g.cx + (lane - 2) * g.lane_w * sc, y)


func _draw() -> void:
	var g := _geometry()
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0b14"))

	# Highway
	var bl := _project(0, 0.0) + Vector2(-g.lane_w * 0.5, 0)
	var br := _project(4, 0.0) + Vector2(g.lane_w * 0.5, 0)
	var tl := _project(0, 1.0) + Vector2(-g.lane_w * 0.5 * 0.32, 0)
	var tr := _project(4, 1.0) + Vector2(g.lane_w * 0.5 * 0.32, 0)
	draw_colored_polygon(PackedVector2Array([bl, tl, tr, br]), Color("171726"))
	for l in range(6):
		var a := _project(0, 0.0) + Vector2((l - 0.5) * g.lane_w, 0)
		var b := _project(0, 1.0) + Vector2((l - 0.5) * g.lane_w * 0.32, 0)
		draw_line(a, b, Color(1, 1, 1, 0.15), 2.0)
	draw_line(Vector2(bl.x, g.hit_y), Vector2(br.x, g.hit_y), Color(1, 1, 1, 0.6), 3.0)

	# Notas (las lejanas primero)
	var vis_notes: Array = []
	var i := next_idx
	while i < notes.size() and notes[i].t <= clock + lookahead:
		if not notes[i].hit:
			vis_notes.append(notes[i])
		i += 1
	vis_notes.reverse()
	for n in vis_notes:
		var t: float = (n.t - clock) / lookahead
		var p := _project(n.lane, clampf(t, -0.1, 1.0))
		var r: float = lerpf(g.lane_w * 0.42, g.lane_w * 0.42 * 0.32, clampf(t, 0.0, 1.0))
		draw_circle(p, r, COLORS[n.lane])
		draw_arc(p, r, 0, TAU, 24, Color.WHITE, 2.0)

	# Botones de traste
	for l in range(5):
		var p := Vector2(g.cx + (l - 2) * g.lane_w, g.hit_y + g.lane_w * 0.55)
		var c: Color = COLORS[l]
		draw_circle(p, g.lane_w * 0.42, c if lane_lit[l] else c.darkened(0.55))
		draw_arc(p, g.lane_w * 0.42, 0, TAU, 24, Color.WHITE, 2.0)

	# HUD
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(30, 50), "Puntos: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	draw_string(font, Vector2(30, 90), "Racha: %d   x%d" % [combo, _multiplier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	draw_string(font, Vector2(size.x - 90, 50), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	if clock < 0.0:
		draw_string(font, Vector2(size.x * 0.5 - 60, size.y * 0.4), "%d" % ceili(-clock), HORIZONTAL_ALIGNMENT_CENTER, 120, 90)

	if paused:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, size.y * 0.35), "PAUSA", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64)
		var r := _exit_rect()
		draw_rect(r, Color("333344"))
		draw_string(font, Vector2(r.position.x, r.position.y + 52), "Salir", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36)
		draw_string(font, Vector2(0, size.y * 0.75), "Toca II para continuar", HORIZONTAL_ALIGNMENT_CENTER, size.x, 24)
