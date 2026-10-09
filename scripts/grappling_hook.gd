extends Node2D
## Grappling hook, fired with the right mouse button towards the cursor.
##
## The hook flies in a straight line (zero gravity). If it hits terrain,
## debris or an enemy it attaches; otherwise it retracts after Params.hook_timeout, or
## sooner if RMB is pressed again while it is still in flight. While
## attached the rope has a desired length (the distance at attach time) and
## only pulls: the player feels nothing while closer than that. Tapping RMB
## while attached releases the hook; holding it reels the rope in, shortening
## the desired length. Debris or an enemy the hook hangs on is pulled too,
## sharing momentum with the player by mass.
##
## Lives as a top_level child of the player, so it draws in global space.

enum State { IDLE, FLYING, ATTACHED, RETRACTING }

const GRAPPLE_MASK := FloatingBody.TERRAIN_LAYER | FloatingBody.DEBRIS_LAYER | FloatingBody.ENEMY_LAYER
const MASS_RATIO := 0.1 ## hook mass as a fraction of the player's
const TAP_TIME := 0.2 ## RMB released sooner than this while attached counts as a tap (release)
const ANCHOR_MISSES := 3 ## frames with nothing solid under the hook before it lets go
const ROPE_COLOR := Color("c8c0a8")
const HOOK_COLOR := Color("8a93a6")
const ROPE_WIDTH := 2.0
const HOOK_SIZE := 9.0
const SQUIGGLE_WAVELENGTH := 28.0 ## px
const SQUIGGLE_MAX_AMPLITUDE := 40.0 ## px

var state := State.IDLE
var rope_length := 0.0 ## desired length while attached

var _player: CharacterBody2D
var _pos := Vector2.ZERO # hook position (global)
var _vel := Vector2.ZERO
var _timer := 0.0
var _anchor_body: CollisionObject2D
var _anchor_local := Vector2.ZERO # attachment point in _anchor_body's frame
var _anchor_misses := 0
var _rmb_down := false
var _reeling := false # RMB pressed while attached and still held
var _press_time := 0.0
var _probe := CircleShape2D.new()


func _ready() -> void:
	_player = get_parent()
	top_level = true
	global_transform = Transform2D.IDENTITY
	show_behind_parent = true


func hook_mass() -> float:
	return Params.player_mass * MASS_RATIO


func anchor_position() -> Vector2:
	if _anchor_body is FloatingBody:
		return _anchor_body.global_position + _anchor_local
	return _anchor_body.to_global(_anchor_local)


func _physics_process(delta: float) -> void:
	_handle_input(delta)
	match state:
		State.FLYING:
			_fly(delta)
		State.ATTACHED:
			_check_anchor()
		State.RETRACTING:
			_retract(delta)
	queue_redraw()


func _handle_input(delta: float) -> void:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var pressed := down and not _rmb_down
	_rmb_down = down
	if pressed:
		if state == State.IDLE:
			_launch()
		elif state == State.FLYING:
			_start_retract()
		elif state == State.ATTACHED:
			_reeling = true
			_press_time = 0.0
	elif _reeling:
		if down:
			_press_time += delta
			_reel(delta)
		else:
			_reeling = false
			if _press_time < TAP_TIME:
				_start_retract()


func _launch() -> void:
	var dir := (_player.get_global_mouse_position() - _player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(_player.rotation)
	_pos = _player.global_position
	_vel = dir * Params.hook_launch_speed
	# Recoil: the hook's momentum comes out of the player's.
	_player.velocity -= _vel * MASS_RATIO
	_timer = 0.0
	state = State.FLYING


func _fly(delta: float) -> void:
	_timer += delta
	var next := _pos + _vel * delta
	var query := PhysicsRayQueryParameters2D.create(_pos, next, GRAPPLE_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_pos = next
		if _timer >= Params.hook_timeout:
			_start_retract()
		return

	_pos = hit["position"]
	var collider: CollisionObject2D = hit["collider"]
	if collider is RigidBody2D:
		collider.apply_impulse(_vel * hook_mass(), _pos - collider.global_position)
	elif collider is FloatingBody:
		collider.velocity += _vel * (hook_mass() / collider.get_mass())
	_attach(collider)
	rope_length = _player.global_position.distance_to(_pos)


## On an enemy the attachment point keeps its offset from the center but
## ignores the enemy's rotation, which only shows where it is facing.
func _attach(body: CollisionObject2D) -> void:
	_anchor_body = body
	_anchor_local = _pos - body.global_position if body is FloatingBody else body.to_local(_pos)
	_anchor_misses = 0
	state = State.ATTACHED


## Keeps the hook on whatever is solid under it: follows debris, switches to a
## piece that split off with the hook on it, and lets go once the ground under
## it has been drilled away.
func _check_anchor() -> void:
	if not is_instance_valid(_anchor_body) or not _anchor_body.is_inside_tree():
		_start_retract()
		return
	_pos = anchor_position()

	_probe.radius = maxf(4.0, Params.collision_tolerance * 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _probe
	query.transform = Transform2D(0.0, _pos)
	query.collision_mask = GRAPPLE_MASK
	var hits := get_world_2d().direct_space_state.intersect_shape(query, 8)
	if hits.is_empty():
		# Freshly rebuilt shapes can take a frame to show up in queries.
		_anchor_misses += 1
		if _anchor_misses >= ANCHOR_MISSES:
			_start_retract()
		return
	_anchor_misses = 0
	for hit in hits:
		if hit["collider"] == _anchor_body:
			return
	_attach(hits[0]["collider"])


## Shortens the desired length, but never more than one frame's reel ahead of a
## player that terrain is holding back.
func _reel(delta: float) -> void:
	var step := Params.hook_reel_speed * delta
	var dist := _player.global_position.distance_to(anchor_position())
	var shortened := maxf(rope_length - step, _player.radius)
	rope_length = maxf(shortened, minf(rope_length, dist - step))


func _retract(delta: float) -> void:
	var to_player := _player.global_position - _pos
	var step := Params.hook_retract_speed * delta
	if to_player.length() <= maxf(step, _player.radius):
		state = State.IDLE
		return
	_pos += to_player.normalized() * step


func _start_retract() -> void:
	state = State.RETRACTING
	_anchor_body = null
	_reeling = false


## Called by the player before it moves. If this frame's motion would carry the
## player past the rope's desired length, an impulse along the rope cuts the
## separating speed to exactly what reaches that length (pulling in any
## stretch, e.g. from reeling). It is shared with debris or an enemy the hook
## is on. Slack
## rope that stays slack does nothing.
func apply_rope(delta: float) -> void:
	if state != State.ATTACHED or not is_instance_valid(_anchor_body):
		return
	var anchor := anchor_position()
	var offset := _player.global_position - anchor
	var dist := offset.length()
	if dist == 0.0:
		return
	var n := offset / dist # from the anchor towards the player

	var inv_mass := 1.0 / Params.player_mass
	var anchor_vel := Vector2.ZERO
	var debris := _anchor_body as RigidBody2D
	if debris != null:
		# Debris spins about its center of mass, so a pull off-center partly
		# turns it instead of dragging it, making it give more easily.
		var arm := anchor - debris.to_global(debris.center_of_mass)
		inv_mass += 1.0 / debris.mass
		if debris.inertia > 0.0:
			inv_mass += pow(arm.cross(n), 2.0) / debris.inertia
		anchor_vel = debris.linear_velocity + debris.angular_velocity * Vector2(-arm.y, arm.x)
	var enemy := _anchor_body as FloatingBody
	if enemy != null:
		inv_mass += 1.0 / enemy.get_mass()
		anchor_vel = enemy.velocity

	var target := (rope_length - dist) / delta # separating speed that ends this frame at rope_length
	var speed := (_player.velocity - anchor_vel).dot(n)
	if speed <= target:
		return
	var impulse := (speed - target) / inv_mass
	_player.velocity -= n * (impulse / Params.player_mass)
	if debris != null:
		debris.apply_impulse(n * impulse, anchor - debris.global_position)
	if enemy != null:
		enemy.velocity += n * (impulse / enemy.get_mass())


func _draw() -> void:
	if state == State.IDLE:
		return
	var from := to_local(_player.global_position)
	var to := to_local(_pos)
	var slack := 1.0
	if state == State.ATTACHED:
		slack = rope_length / maxf(from.distance_to(to), 1.0)
	_draw_rope(from, to, slack)

	var dir := (to - from).normalized()
	if dir == Vector2.ZERO:
		dir = _vel.normalized()
	var back := to - dir * HOOK_SIZE
	var side := dir.orthogonal() * HOOK_SIZE * 0.6
	draw_colored_polygon(PackedVector2Array([to, back + side, back - side]), HOOK_COLOR)


## Straight when taut. Slack rope is drawn as a sine wave whose amplitude makes
## its arc length roughly the rope length (arc ≈ gap * (1 + (πA/λ)²) for small
## amplitudes), so it gets squigglier the more slack there is. The wave is
## measured from the hook with a fixed wavelength, so it starts at phase 0 on
## the hook and stays put there as the player moves; it tapers off over the
## last half wavelength to meet the player.
func _draw_rope(from: Vector2, to: Vector2, slack: float) -> void:
	var gap := from.distance_to(to)
	if slack <= 1.0 or gap < 1.0:
		draw_line(from, to, ROPE_COLOR, ROPE_WIDTH, true)
		return
	var amplitude := minf(SQUIGGLE_WAVELENGTH / PI * sqrt(slack - 1.0), SQUIGGLE_MAX_AMPLITUDE)
	var dir := (from - to) / gap # from the hook towards the player
	var normal := dir.orthogonal()
	var taper := SQUIGGLE_WAVELENGTH * 0.5
	var segments := maxi(8, ceili(gap / SQUIGGLE_WAVELENGTH * 16.0))
	var points := PackedVector2Array()
	for i in segments + 1:
		var s := gap * i / segments # distance from the hook
		var envelope := smoothstep(0.0, taper, gap - s)
		var wave := sin(TAU * s / SQUIGGLE_WAVELENGTH) * amplitude * envelope
		points.append(to + dir * s + normal * wave)
	draw_polyline(points, ROPE_COLOR, ROPE_WIDTH, true)
