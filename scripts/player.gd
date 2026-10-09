extends CharacterBody2D
## Side-view, zero-gravity player. A spring pulls it towards the mouse cursor;
## with damping_ratio = 1 the spring is critically damped, so it settles on the
## cursor without overshoot. Acceleration is proportional to distance, capped at
## max_accel (so far from the cursor it is constant).

const BODY_COLOR := Color("e0a526")
const NOSE_COLOR := Color("2b2f3a")

var radius := 20.0

@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	shape.shape = CircleShape2D.new()
	Params.changed.connect(_apply_size)
	Params.restart_requested.connect(_restart)
	_apply_size()
	_restart()


func _restart() -> void:
	global_position = get_viewport_rect().size / 2.0
	velocity = Vector2.ZERO
	rotation = 0.0


func _apply_size() -> void:
	radius = get_viewport_rect().size.x * Params.size_fraction / 2.0
	(shape.shape as CircleShape2D).radius = radius
	queue_redraw()


func _physics_process(delta: float) -> void:
	var to_cursor := get_global_mouse_position() - global_position

	var k := Params.stiffness
	var accel := to_cursor * k - velocity * (2.0 * Params.damping_ratio * sqrt(k))
	accel = accel.limit_length(Params.max_accel)
	velocity = (velocity + accel * delta).limit_length(Params.max_speed)
	move_and_slide()

	if to_cursor.length() > Params.turn_threshold:
		rotation = rotate_toward(rotation, to_cursor.angle(), Params.turn_speed * delta)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, BODY_COLOR)
	# Nose shows facing direction (+X is forward).
	draw_line(Vector2.ZERO, Vector2(radius, 0.0), NOSE_COLOR, maxf(2.0, radius * 0.15))
