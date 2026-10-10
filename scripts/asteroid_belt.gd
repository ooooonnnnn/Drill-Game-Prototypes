extends Node2D
## Asteroid belt: a vertical strip left of the terrain, HEIGHT_SCREENS screens
## tall with its bottom level with the terrain's, Params.belt_width_fraction
## screens wide. Every Params.asteroid_interval seconds an asteroid spawns at
## the top, at an evenly distributed horizontal position that keeps it wholly
## inside the strip, and falls at Params.asteroid_speed until it reaches the
## bottom, where it despawns. Asteroids erase the terrain and debris they touch
## and destroy the player and enemies on contact.

const Asteroid := preload("res://scripts/asteroid.gd")
const HEIGHT_SCREENS := 3.0
const STRIP_COLOR := Color(1, 1, 1, 0.04)

@export var terrain: Node2D

var _timer := 0.0


func _ready() -> void:
	Params.changed.connect(queue_redraw)


func strip_rect() -> Rect2:
	var screen := get_viewport_rect().size
	var width := screen.x * Params.belt_width_fraction
	var height := screen.y * HEIGHT_SCREENS
	return Rect2(-width, screen.y - height, width, height)


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= Params.asteroid_interval:
		_timer = 0.0
		_spawn()

	var strip := strip_rect()
	for asteroid: Asteroid in get_children():
		var pos := asteroid.global_position
		terrain.erase_path(asteroid.previous_position, pos, asteroid.radius)
		asteroid.previous_position = pos
		for body: FloatingBody in get_tree().get_nodes_in_group(FloatingBody.GROUP):
			if pos.distance_to(body.global_position) < asteroid.radius + body.radius:
				body.destroy()
		if pos.y + asteroid.radius >= strip.end.y:
			asteroid.queue_free()


func _spawn() -> void:
	var strip := strip_rect()
	var r := Params.asteroid_radius
	var min_x := strip.position.x + r
	var max_x := strip.end.x - r
	var x := randf_range(min_x, max_x) if max_x > min_x else strip.get_center().x
	var asteroid := Asteroid.new()
	asteroid.setup(r, Params.asteroid_mass, Vector2(0.0, Params.asteroid_speed))
	asteroid.position = Vector2(x, strip.position.y + r)
	asteroid.previous_position = asteroid.position
	add_child(asteroid)


func _draw() -> void:
	draw_rect(strip_rect(), STRIP_COLOR)
