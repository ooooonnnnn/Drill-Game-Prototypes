extends FloatingBody
## Basic enemy: accelerates straight at the player at a constant
## Params.enemy_max_accel, its speed limited by linear friction to
## Params.enemy_max_speed (like the player outside its spring radius). When it
## touches the player, an impulse along the line between them sets them
## separating at Params.enemy_knockback, split between the two by mass. A
## collision whose impulse on it exceeds Params.enemy_break_impulse destroys it;
## the recoil from knocking the player away doesn't count, but the part of the
## impulse that stops a player ramming into it does.

signal impacted(impulse: float) ## a collision gave it at least MIN_REPORTED_IMPULSE

const MIN_REPORTED_IMPULSE := 1000.0 ## ignores the small per-frame impulses of resting contact
const BODY_COLOR := Color("8e5bd6")
const START_POSITION_FRACTION := Vector2(0.15, 0.1) ## spawn point as a fraction of the screen

@export var player: FloatingBody


func _ready() -> void:
	super()
	global_position = get_viewport_rect().size * START_POSITION_FRACTION


func get_mass() -> float:
	return Params.enemy_mass


func body_color() -> Color:
	return BODY_COLOR


func _felt_impact(impulse: float) -> void:
	if impulse >= MIN_REPORTED_IMPULSE:
		impacted.emit(impulse)
	if impulse > Params.enemy_break_impulse:
		queue_free()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): # destroyed: coast to a stop
		_accelerate_with_friction(Vector2.ZERO, Params.enemy_max_accel / Params.enemy_max_speed, delta)
		_move_and_slide_along_surfaces(delta)
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player / distance if distance > 0.0 else Vector2.ZERO
	var friction := Params.enemy_max_accel / Params.enemy_max_speed
	_accelerate_with_friction(direction * Params.enemy_max_accel, friction, delta)
	_move_and_slide_along_surfaces(delta)

	if distance > radius:
		rotation = rotate_toward(rotation, to_player.angle(), Params.turn_speed * delta)


func _bumped(other: FloatingBody) -> void:
	if other != player:
		return
	var offset := player.global_position - global_position
	var distance := offset.length()
	if distance == 0.0:
		return
	var n := offset / distance # from the enemy towards the player
	var separating_speed := (player.velocity - velocity).dot(n)
	if separating_speed >= Params.enemy_knockback:
		return
	var impulse := (Params.enemy_knockback - separating_speed) \
			/ (1.0 / get_mass() + 1.0 / player.get_mass())
	velocity -= n * (impulse / get_mass())
	player.velocity += n * (impulse / player.get_mass())
	# The knockback itself is the part pushing them apart from at rest to
	# enemy_knockback; anything above that stopped the player closing in.
	var knockback_impulse := (Params.enemy_knockback - maxf(separating_speed, 0.0)) \
			/ (1.0 / get_mass() + 1.0 / player.get_mass())
	unfelt_velocity_change -= n * (knockback_impulse / get_mass())
