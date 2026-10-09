extends FloatingBody
## Side-view, zero-gravity player, driven towards the mouse cursor. Outside
## spring_radius it accelerates at a constant max_accel; inside, a spring pulls
## it in, its constant chosen so it gives max_accel at the radius. Speed is
## limited by linear friction rather than a hard cap: friction =
## max_accel / max_speed, so full acceleration settles at max_speed. Inside the
## radius the friction uses max_speed_inside instead, and is the spring's only
## damping.

const BODY_COLOR := Color("e0a526")
const DRILL_COLOR := Color("e03a2b")
const START_HEIGHT_FRACTION := 0.1 ## spawn height as a fraction of screen height

var _drilling := false

@onready var hook: Node2D = $GrapplingHook


func _ready() -> void:
	super()
	_restart()


func _restart() -> void:
	var screen := get_viewport_rect().size
	global_position = Vector2(screen.x / 2.0, screen.y * START_HEIGHT_FRACTION)
	velocity = Vector2.ZERO
	rotation = 0.0


func get_mass() -> float:
	return Params.player_mass


func body_color() -> Color:
	return DRILL_COLOR if _drilling else BODY_COLOR


## The player drills only while the left mouse button is held.
func is_drilling() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _physics_process(delta: float) -> void:
	# Drilling passes through terrain (the terrain erases itself around the
	# player); otherwise terrain is solid. Enemies are always solid.
	var drilling := is_drilling()
	collision_mask = ENEMY_LAYER if drilling else TERRAIN_LAYER | DEBRIS_LAYER | ENEMY_LAYER
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
