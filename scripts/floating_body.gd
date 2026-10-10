class_name FloatingBody
extends CharacterBody2D
## Shared base for the player and enemies: a zero-gravity disc (sized by
## Params.size_fraction, drawn with a nose showing its facing) that is driven
## against linear friction, slides along terrain and shoves debris.

const MassLabel := preload("res://scripts/mass_label.gd")

const NOSE_COLOR := Color("2b2f3a")
const PLAYER_LAYER := 1
const TERRAIN_LAYER := 2
const DEBRIS_LAYER := 4
const ENEMY_LAYER := 8

var radius := 20.0
## Part of this body's velocity change in the current collision that
## _felt_impact should not count. Set by _bumped; cleared after each collision.
var unfelt_velocity_change := Vector2.ZERO

@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	shape.shape = CircleShape2D.new()
	add_child(MassLabel.new())
	Params.changed.connect(_apply_size)
	_apply_size()


## Overridden by subclasses.
func get_mass() -> float:
	return 1.0


## Overridden by subclasses.
func body_color() -> Color:
	return Color.WHITE


## Called on both bodies whenever either one runs into the other, so a contact
## is seen no matter which of them was moving. Overridden by subclasses.
func _bumped(_other: FloatingBody) -> void:
	pass


## Called with the size of the impulse (mass * change in velocity) a collision
## gave this body. Overridden by subclasses.
func _felt_impact(_impulse: float) -> void:
	pass


func _apply_size() -> void:
	radius = get_viewport_rect().size.x * Params.size_fraction / 2.0
	(shape.shape as CircleShape2D).radius = radius
	queue_redraw()


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
		var collider := collision.get_collider()
		var other := collider as FloatingBody
		var velocity_before := velocity
		var other_velocity_before := other.velocity if other != null else Vector2.ZERO
		if collider is RigidBody2D:
			_push_debris(collider, collision)
		else:
			# Bodies resolve their contact first, so the closing speed is still
			# there to be exchanged; the slide only stops what is left of it.
			if other != null:
				_bumped(other)
				other._bumped(self)
			if velocity.dot(normal) < 0.0:
				velocity = velocity.slide(normal)
		if other != null:
			other._felt_impact(other.get_mass() \
					* (other.velocity - other_velocity_before - other.unfelt_velocity_change).length())
			other.unfelt_velocity_change = Vector2.ZERO
		_felt_impact(get_mass() * (velocity - velocity_before - unfelt_velocity_change).length())
		unfelt_velocity_change = Vector2.ZERO
		motion = collision.get_remainder().slide(normal)
		if motion.length_squared() < 0.0001:
			return


## Perfectly inelastic collision with a rigid body: both end up moving at the
## same speed along the contact normal, with momentum shared by mass.
func _push_debris(debris: RigidBody2D, collision: KinematicCollision2D) -> void:
	var normal := collision.get_normal() # points from the debris towards this body
	var closing_speed := (velocity - debris.linear_velocity).dot(-normal)
	if closing_speed <= 0.0:
		return
	var impulse := closing_speed / (1.0 / get_mass() + 1.0 / debris.mass)
	debris.apply_impulse(-normal * impulse, collision.get_position() - debris.global_position)
	velocity += normal * (impulse / get_mass())


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, body_color())
	# Nose shows facing direction (+X is forward).
	draw_line(Vector2.ZERO, Vector2(radius, 0.0), NOSE_COLOR, maxf(2.0, radius * 0.15))
