extends Node2D
## Child of a physics body that draws "Mass: xxx" upright over the body's center
## of mass. Dark text on a light backing, so it reads on every body color and on
## the background.

const FONT_SIZE := 14
const PADDING := Vector2(4, 1)
const TEXT_COLOR := Color("1a1c26")
const BACKING_COLOR := Color(1, 1, 1, 0.85)
const BACKING_BORDER_COLOR := Color("1a1c26")

@onready var body: PhysicsBody2D = get_parent()


func _ready() -> void:
	top_level = true # stays upright while the body rotates
	z_index = 10 # above the other bodies


func _process(_delta: float) -> void:
	var center := Vector2.ZERO
	if body is RigidBody2D:
		center = (body as RigidBody2D).center_of_mass
	global_position = body.to_global(center)
	queue_redraw()


func _mass() -> float:
	if body is RigidBody2D:
		return (body as RigidBody2D).mass
	return body.get_mass()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var text := "Mass: %s" % str(snappedf(_mass(), 0.1))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var backing := Rect2(-text_size / 2.0 - PADDING, text_size + PADDING * 2.0)
	draw_rect(backing, BACKING_COLOR)
	draw_rect(backing, BACKING_BORDER_COLOR, false, 1.0)
	var baseline := Vector2(-text_size.x / 2.0, font.get_ascent(FONT_SIZE) - text_size.y / 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
