extends CharacterBody2D
## Side-view, zero-gravity player, driven towards the mouse cursor. Outside
## spring_radius it accelerates at a constant max_accel; inside, a spring pulls
## it in, its constant chosen so it gives max_accel at the radius. Speed is
## limited by linear friction rather than a hard cap: friction =
## max_accel / max_speed, so full acceleration settles at max_speed. Inside the
## radius the friction uses max_speed_inside instead, and is the spring's only
## damping.

const BODY_COLOR := Color("e0a526")
const DRILL_COLOR := Color("e03a2b")
const NOSE_COLOR := Color("2b2f3a")
const TERRAIN_LAYER := 2
const DEBRIS_LAYER := 4
const START_HEIGHT_FRACTION := 0.1 ## spawn height as a fraction of screen height

var _drilling := false

var radius := 20.0

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var hook: Node2D = $GrapplingHook


func _ready() -> void:
	shape.shape = CircleShape2D.new()
	Params.changed.connect(_apply_size)
	_apply_size()
	_restart()


func _restart() -> void:
	var screen := get_viewport_rect().size
	global_position = Vector2(screen.x / 2.0, screen.y * START_HEIGHT_FRACTION)
	velocity = Vector2.ZERO
	rotation = 0.0


func _apply_size() -> void:
	radius = get_viewport_rect().size.x * Params.size_fraction / 2.0
	(shape.shape as CircleShape2D).radius = radius
	queue_redraw()


## The player drills only while the left mouse button is held.
func is_drilling() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _physics_process(delta: float) -> void:
	# Drilling passes through terrain (the terrain erases itself around the
	# player); otherwise terrain is solid.
	var drilling := is_drilling()
	collision_mask = 0 if drilling else TERRAIN_LAYER | DEBRIS_LAYER
	if drilling != _drilling:
		_drilling = drilling
		queue_redraw()

	var to_cursor := get_global_mouse_position() - global_position

	var distance := to_cursor.length()
	if distance > Params.spring_radius:
		var drive := to_cursor / distance * Params.max_accel
		_accelerate_with_friction(drive, Params.max_accel / Params.max_speed, delta)
	else:
		var k := Params.max_accel / Params.spring_radius
		_accelerate_with_friction(to_cursor * k, Params.max_accel / Params.max_speed_inside, delta)
	hook.apply_rope(delta)
	_move_and_slide_along_surfaces(delta)

	if distance > radius: # no meaningful direction with the cursor over the body
		rotation = rotate_toward(rotation, to_cursor.angle(), Params.turn_speed * delta)


## Integrates dv/dt = drive - friction * v exactly over the step (drive held
## constant), so a strong friction can't overshoot. Under a steady drive the
## velocity settles at drive / friction.
func _accelerate_with_friction(drive: Vector2, friction: float, delta: float) -> void:
	var terminal := drive / friction
	velocity = terminal + (velocity - terminal) * exp(-friction * delta)


## Replaces move_and_slide(): in floating mode it keeps the velocity component
## pushing into a surface, and it rescales the slid motion to the full leftover
## length, so a body pressed against terrain slides at close to full speed and
## releases its stored-up velocity when it clears the edge. Here the normal
## component is removed from velocity on every hit and the remainder keeps its
## natural (projected) length.
func _move_and_slide_along_surfaces(delta: float) -> void:
	var motion := velocity * delta
	for i in 4:
		var collision := move_and_collide(motion)
		if collision == null:
			return
		var normal := collision.get_normal()
		var debris := collision.get_collider() as RigidBody2D
		if debris != null:
			_push_debris(debris, collision)
		else:
			velocity = velocity.slide(normal)
		motion = collision.get_remainder().slide(normal)
		if motion.length_squared() < 0.0001:
			return


## Perfectly inelastic collision with a rigid body: both end up moving at the
## same speed along the contact normal, with momentum shared by mass.
func _push_debris(debris: RigidBody2D, collision: KinematicCollision2D) -> void:
	var normal := collision.get_normal() # points from the debris towards the player
	var closing_speed := (velocity - debris.linear_velocity).dot(-normal)
	if closing_speed <= 0.0:
		return
	var impulse := closing_speed / (1.0 / Params.player_mass + 1.0 / debris.mass)
	debris.apply_impulse(-normal * impulse, collision.get_position() - debris.global_position)
	velocity += normal * (impulse / Params.player_mass)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, DRILL_COLOR if _drilling else BODY_COLOR)
	# Nose shows facing direction (+X is forward).
	draw_line(Vector2.ZERO, Vector2(radius, 0.0), NOSE_COLOR, maxf(2.0, radius * 0.15))
