extends Node2D
## Hoop Rush: a 60-second 2D basketball shooter.
## Move with A/D or the arrow keys, aim with the mouse,
## hold the left mouse button to charge a shot and release to shoot.

enum State { MENU, PLAYING, OVER }

const W := 1280.0
const H := 720.0
const FLOOR_Y := 640.0
const GRAVITY := 1500.0
const BALL_R := 18.0
const RIM_R := 5.0
const RIM_HALF := 42.0
const BOUNCE := 0.62
const MOVE_SPEED := 340.0
const PLAYER_MIN_X := 80.0
const PLAYER_MAX_X := 620.0
const THREE_PT_X := 330.0
const ROUND_TIME := 60.0
const MIN_SPEED := 450.0
const MAX_SPEED := 1350.0
const SAVE_PATH := "user://hoop_rush.cfg"

var state: State = State.MENU
var time_left := ROUND_TIME
var score := 0
var high_score := 0
var streak := 0
var shots := 0
var makes := 0

var player_x := 200.0
var hoop_x := 1060.0
var rim_y := 300.0
var hoop_base_y := 300.0
var hoop_t := 0.0

var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_in_air := false
var ball_air_time := 0.0
var touched_rim := false
var scored_this_shot := false
var shot_from_x := 0.0
var trail: Array[Vector2] = []

var charging := false
var charge := 0.0
var charge_dir := 1.0
var mouse_was_down := false

var popups: Array = []  # each: {text, pos, t, color}
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	_load_high_score()
	_reset_ball()


func _process(delta: float) -> void:
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var clicked := mouse_down and not mouse_was_down
	var released := mouse_was_down and not mouse_down
	mouse_was_down = mouse_down

	match state:
		State.MENU:
			if clicked or Input.is_key_pressed(KEY_SPACE):
				_start_game()
		State.OVER:
			if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_SPACE):
				_start_game()
		State.PLAYING:
			_update_game(delta, clicked, released)

	_update_popups(delta)
	queue_redraw()


func _start_game() -> void:
	state = State.PLAYING
	time_left = ROUND_TIME
	score = 0
	streak = 0
	shots = 0
	makes = 0
	player_x = 200.0
	hoop_t = 0.0
	rim_y = hoop_base_y
	popups.clear()
	_reset_ball()


func _end_game() -> void:
	state = State.OVER
	charging = false
	if score > high_score:
		high_score = score
		_save_high_score()


func _update_game(delta: float, clicked: bool, released: bool) -> void:
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_end_game()
		return

	# Hoop starts moving once the player has proven they can score.
	if score >= 10:
		hoop_t += delta
		var amp := 60.0 if score < 25 else 110.0
		rim_y = hoop_base_y + sin(hoop_t * 1.6) * amp

	# Player movement (locked while the ball is in the air).
	if not ball_in_air:
		var dir := 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir += 1.0
		player_x = clamp(player_x + dir * MOVE_SPEED * delta, PLAYER_MIN_X, PLAYER_MAX_X)
		ball_pos = _hand_pos()

		# Charging uses a ping-pong meter so timing the release is the skill.
		if clicked:
			charging = true
			charge = 0.0
			charge_dir = 1.0
		if charging:
			charge += charge_dir * delta * 1.1
			if charge >= 1.0:
				charge = 1.0
				charge_dir = -1.0
			elif charge <= 0.0:
				charge = 0.0
				charge_dir = 1.0
		if released and charging:
			_shoot()
	else:
		_update_ball(delta)


func _hand_pos() -> Vector2:
	return Vector2(player_x + 22.0, FLOOR_Y - 118.0)


func _aim_dir() -> Vector2:
	var d := get_global_mouse_position() - _hand_pos()
	if d.length() < 1.0:
		return Vector2(1, -1).normalized()
	d = d.normalized()
	# Never allow shooting downward or backward too far.
	if d.y > -0.15:
		d.y = -0.15
		d = d.normalized()
	return d


func _shot_speed() -> float:
	return lerp(MIN_SPEED, MAX_SPEED, charge)


func _shoot() -> void:
	charging = false
	ball_in_air = true
	ball_air_time = 0.0
	touched_rim = false
	scored_this_shot = false
	shot_from_x = player_x
	ball_vel = _aim_dir() * _shot_speed()
	trail.clear()
	shots += 1


func _reset_ball() -> void:
	ball_in_air = false
	ball_vel = Vector2.ZERO
	ball_pos = _hand_pos()
	trail.clear()


func _rim_points() -> Array[Vector2]:
	return [Vector2(hoop_x - RIM_HALF, rim_y), Vector2(hoop_x + RIM_HALF, rim_y)]


func _update_ball(delta: float) -> void:
	ball_air_time += delta
	# Substeps keep fast shots from tunneling through the rim.
	var steps := 4
	var dt := delta / steps
	for i in steps:
		var prev := ball_pos
		ball_vel.y += GRAVITY * dt
		ball_pos += ball_vel * dt
		_collide(prev)

	trail.append(ball_pos)
	if trail.size() > 14:
		trail.remove_at(0)

	var out: bool = ball_pos.x > W + 60.0 or ball_pos.x < -60.0
	var settled: bool = ball_pos.y >= FLOOR_Y - BALL_R - 1.0 and abs(ball_vel.y) < 60.0
	if out or settled or ball_air_time > 4.0:
		if not scored_this_shot:
			if streak >= 3:
				_popup("Streak over", ball_pos.clamp(Vector2(60, 60), Vector2(W - 60, H - 60)), Color(0.9, 0.5, 0.5))
			streak = 0
		_reset_ball()


func _collide(prev: Vector2) -> void:
	# Rim: two small circles at each edge of the hoop.
	for p in _rim_points():
		var diff := ball_pos - p
		var dist := diff.length()
		var min_d := BALL_R + RIM_R
		if dist < min_d and dist > 0.001:
			var n := diff / dist
			ball_pos = p + n * min_d
			var vn := ball_vel.dot(n)
			if vn < 0.0:
				ball_vel -= (1.0 + BOUNCE) * vn * n
				ball_vel *= 0.92
			touched_rim = true

	# Backboard: a vertical segment just behind the back rim.
	var bx := hoop_x + RIM_HALF + 14.0
	var top := rim_y - 135.0
	var bottom := rim_y + 12.0
	if ball_pos.y > top and ball_pos.y < bottom:
		if ball_pos.x + BALL_R > bx and prev.x + BALL_R <= bx + 2.0 and ball_vel.x > 0.0:
			ball_pos.x = bx - BALL_R
			ball_vel.x = -ball_vel.x * 0.55

	# Floor and side walls.
	if ball_pos.y > FLOOR_Y - BALL_R:
		ball_pos.y = FLOOR_Y - BALL_R
		ball_vel.y = -ball_vel.y * 0.55
		ball_vel.x *= 0.85
	if ball_pos.y < -400.0:
		ball_vel.y = abs(ball_vel.y) * 0.2

	# Scoring: ball center crosses rim height moving down, between the rim edges.
	if not scored_this_shot and ball_vel.y > 0.0 and prev.y < rim_y and ball_pos.y >= rim_y:
		var inner := RIM_HALF - RIM_R - 4.0
		if abs(ball_pos.x - hoop_x) < inner:
			_score_basket()


func _score_basket() -> void:
	scored_this_shot = true
	makes += 1
	streak += 1
	var pts := 3 if shot_from_x < THREE_PT_X else 2
	var label := "+%d" % pts
	if not touched_rim:
		pts += 1
		label = "SWISH +%d" % pts
	if streak >= 3:
		pts *= 2
		label += "  x2 ON FIRE"
	score += pts
	# Every make adds a little time back so good streaks keep the round alive.
	time_left = min(time_left + 1.5, ROUND_TIME)
	var col := Color(1.0, 0.55, 0.15) if streak >= 3 else Color(1, 1, 1)
	_popup(label, Vector2(hoop_x - 60.0, rim_y - 60.0), col)


func _popup(text: String, pos: Vector2, color: Color) -> void:
	popups.append({"text": text, "pos": pos, "t": 1.2, "color": color})


func _update_popups(delta: float) -> void:
	for p in popups:
		p["t"] -= delta
		p["pos"] += Vector2(0, -40.0 * delta)
	popups = popups.filter(func(p): return p["t"] > 0.0)


# ---------- Persistence ----------

func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("stats", "high_score", 0))


func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "high_score", high_score)
	cfg.save(SAVE_PATH)


# ---------- Drawing ----------

func _draw() -> void:
	_draw_court()
	_draw_hoop()
	if state == State.PLAYING and not ball_in_air and charging:
		_draw_trajectory()
	_draw_player()
	_draw_ball()
	_draw_hud()
	for p in popups:
		var a: float = clamp(p["t"] / 1.2, 0.0, 1.0)
		var c: Color = p["color"]
		c.a = a
		draw_string(font, p["pos"], p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, c)
	if state == State.MENU:
		_draw_overlay("HOOP RUSH", [
			"A / D or arrows to move",
			"Aim with the mouse, hold left click to charge, release to shoot",
			"Shots from behind the line are worth 3. Swishes add 1.",
			"Hit 3 in a row to catch fire for double points.",
			"",
			"Click or press Space to start",
			"Best: %d" % high_score,
		])
	elif state == State.OVER:
		var pct := 0 if shots == 0 else int(round(100.0 * makes / shots))
		var lines := [
			"Score: %d" % score,
			"Shooting: %d / %d  (%d%%)" % [makes, shots, pct],
			"Best: %d" % high_score,
			"",
			"Press R or Space to play again",
		]
		if score == high_score and score > 0:
			lines.insert(0, "New high score!")
		_draw_overlay("TIME", lines)


func _draw_court() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.1, 0.16))
	# Gym wall bands.
	for i in 6:
		draw_rect(Rect2(0, 80 + i * 90, W, 2), Color(1, 1, 1, 0.03))
	# Wood floor.
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color(0.62, 0.42, 0.24))
	for i in 20:
		draw_line(Vector2(i * 70, FLOOR_Y), Vector2(i * 70 - 30, H), Color(0, 0, 0, 0.12), 2)
	draw_line(Vector2(0, FLOOR_Y), Vector2(W, FLOOR_Y), Color(1, 1, 1, 0.5), 3)
	# Three-point line marker.
	draw_line(Vector2(THREE_PT_X, FLOOR_Y), Vector2(THREE_PT_X, H), Color(1, 1, 1, 0.8), 4)
	draw_string(font, Vector2(THREE_PT_X - 60, FLOOR_Y + 40), "3PT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))


func _draw_hoop() -> void:
	var bx := hoop_x + RIM_HALF + 14.0
	# Pole and arm.
	draw_rect(Rect2(bx + 40, rim_y - 60, 14, FLOOR_Y - rim_y + 60), Color(0.35, 0.37, 0.42))
	draw_line(Vector2(bx + 6, rim_y - 50), Vector2(bx + 47, rim_y - 50), Color(0.35, 0.37, 0.42), 8)
	# Backboard.
	draw_rect(Rect2(bx, rim_y - 135, 8, 147), Color(0.92, 0.94, 0.98))
	draw_rect(Rect2(bx - 2, rim_y - 70, 4, 40), Color(0.85, 0.2, 0.2))
	# Net.
	var net_col := Color(1, 1, 1, 0.7)
	var l := hoop_x - RIM_HALF
	var r := hoop_x + RIM_HALF
	for i in 5:
		var t := i / 4.0
		var top_x: float = lerp(l, r, t)
		var bot_x: float = lerp(l + 14.0, r - 14.0, t)
		draw_line(Vector2(top_x, rim_y), Vector2(bot_x, rim_y + 52), net_col, 1.5)
	draw_line(Vector2(l + 7, rim_y + 26), Vector2(r - 7, rim_y + 26), net_col, 1.5)
	draw_line(Vector2(l + 14, rim_y + 52), Vector2(r - 14, rim_y + 52), net_col, 1.5)
	# Rim.
	draw_line(Vector2(l, rim_y), Vector2(bx, rim_y), Color(0.95, 0.35, 0.1), 5)
	for p in _rim_points():
		draw_circle(p, RIM_R, Color(0.95, 0.35, 0.1))


func _draw_player() -> void:
	var x := player_x
	var feet := FLOOR_Y
	var body := Color(0.2, 0.55, 0.95)
	var skin := Color(0.45, 0.3, 0.2)
	# Legs.
	draw_line(Vector2(x - 8, feet - 40), Vector2(x - 12, feet), Color(0.15, 0.15, 0.2), 8)
	draw_line(Vector2(x + 8, feet - 40), Vector2(x + 12, feet), Color(0.15, 0.15, 0.2), 8)
	# Torso (jersey).
	draw_rect(Rect2(x - 16, feet - 92, 32, 54), body)
	draw_string(font, Vector2(x - 9, feet - 56), "23", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	# Head.
	draw_circle(Vector2(x, feet - 108), 14, skin)
	# Shooting arm points toward the ball when holding it.
	var hand := _hand_pos() if not ball_in_air else Vector2(x + 30, feet - 140)
	draw_line(Vector2(x + 10, feet - 86), hand, skin, 6)


func _draw_ball() -> void:
	for i in trail.size():
		var a: float = float(i) / trail.size() * 0.35
		draw_circle(trail[i], BALL_R * (0.4 + 0.5 * float(i) / trail.size()), Color(1, 0.55, 0.15, a))
	draw_circle(ball_pos, BALL_R, Color(0.95, 0.5, 0.12))
	draw_arc(ball_pos, BALL_R, 0, TAU, 24, Color(0.25, 0.12, 0.05), 2)
	draw_line(ball_pos + Vector2(-BALL_R, 0), ball_pos + Vector2(BALL_R, 0), Color(0.25, 0.12, 0.05), 2)
	draw_line(ball_pos + Vector2(0, -BALL_R), ball_pos + Vector2(0, BALL_R), Color(0.25, 0.12, 0.05), 2)


func _draw_trajectory() -> void:
	# Short dotted preview of the first part of the arc so aiming is learnable
	# but the full path (and the make) still depends on the player's judgment.
	var pos := _hand_pos()
	var vel := _aim_dir() * _shot_speed()
	var dt := 1.0 / 30.0
	for i in 12:
		vel.y += GRAVITY * dt
		pos += vel * dt
		draw_circle(pos, 3.5, Color(1, 1, 1, 0.55 - i * 0.04))
	# Power meter.
	var m := Rect2(player_x - 40, FLOOR_Y - 160, 80, 10)
	draw_rect(m, Color(0, 0, 0, 0.5))
	var fill := Color(0.3, 0.9, 0.4).lerp(Color(1.0, 0.35, 0.2), charge)
	draw_rect(Rect2(m.position, Vector2(m.size.x * charge, m.size.y)), fill)


func _draw_hud() -> void:
	draw_string(font, Vector2(30, 50), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_string(font, Vector2(30, 85), "BEST %d" % high_score, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.6))
	var tcol := Color.WHITE if time_left > 10.0 else Color(1.0, 0.4, 0.3)
	draw_string(font, Vector2(W / 2.0 - 40, 50), "%.1f" % time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, tcol)
	if streak >= 2:
		var c := Color(1.0, 0.55, 0.15) if streak >= 3 else Color(1, 1, 1, 0.8)
		draw_string(font, Vector2(W - 260, 50), "STREAK %d" % streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, c)


func _draw_overlay(title: String, lines: Array) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(0, 220), title, HORIZONTAL_ALIGNMENT_CENTER, W, 72, Color(1.0, 0.55, 0.15))
	var y := 300.0
	for line in lines:
		draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color.WHITE)
		y += 38.0
