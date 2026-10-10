extends RigidBody2D
## A falling asteroid: an inertial disc with no gravity or damping, so it keeps
## the velocity it spawns with. It collides physically only with debris, which
## it shoves aside by mass; AsteroidBelt handles its other contacts and erases
## the terrain it touches.

const MassLabel := preload("res://scripts/mass_label.gd")
const ASTEROID_LAYER := 16
const DEBRIS_LAYER := 4
const BODY_COLOR := Color("8a8f99")
const RIM_COLOR := Color("5b606b")

var radius := 40.0
var previous_position := Vector2.ZERO ## global; start of this frame's swept path


func setup(p_radius: float, p_mass: float, velocity: Vector2) -> void:
	radius = p_radius
	mass = p_mass
	linear_velocity = velocity
	gravity_scale = 0.0
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	collision_layer = ASTEROID_LAYER
	collision_mask = DEBRIS_LAYER
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	add_child(MassLabel.new())


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, BODY_COLOR)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, RIM_COLOR, maxf(2.0, radius * 0.08))
