extends Node2D
## Destructible terrain. The authoritative state is a CPU-side RGBA image:
## alpha 1 = solid, alpha 0 = drilled away. It is shown by shaders/terrain.gdshader
## and turned into a collider (an estimated outline, simplified by
## Params.collision_tolerance) whenever the player stops drilling.
##
## While drilling the player's terrain collision is off (see player.gd); the
## collider is rebuilt on release, before collision is switched back on.

const ERASE_MARGIN := 1.0 ## extra px erased around the player so it never starts inside solid terrain
const START_CAVITY_FACTOR := 2.0 ## starting cavity radius, in player radii

@export var player: Node2D
@export var terrain_size := Vector2i(1120, 560)

@onready var fill: ColorRect = $Fill
@onready var shape_node: CollisionShape2D = $Body/CollisionShape2D

var _image: Image
var _texture: ImageTexture
var _outline := ConcavePolygonShape2D.new()
var _prev := Vector2.INF
var _texture_dirty := false
var _collision_dirty := false


func _ready() -> void:
	_image = Image.create(terrain_size.x, terrain_size.y, false, Image.FORMAT_RGBA8)
	_image.fill(Color.WHITE)

	# Carve a starting cavity around the spot the player spawns in.
	var spawn := get_viewport_rect().size / 2.0 - global_position
	var player_radius := get_viewport_rect().size.x * Params.size_fraction / 2.0
	_erase_circle(spawn, player_radius * START_CAVITY_FACTOR)

	_texture = ImageTexture.create_from_image(_image)
	fill.size = Vector2(terrain_size)
	(fill.material as ShaderMaterial).set_shader_parameter("solid_mask", _texture)
	shape_node.shape = _outline
	_rebuild_collision()


func _physics_process(_delta: float) -> void:
	if player.is_drilling():
		var pos := to_local(player.global_position)
		var radius: float = player.radius + ERASE_MARGIN
		var from := pos if _prev == Vector2.INF else _prev
		# Stamp along the path so fast movement leaves no gaps.
		var step := maxf(1.0, radius * 0.5)
		var steps := ceili(from.distance_to(pos) / step)
		for i in range(1, steps + 1):
			_erase_circle(from.lerp(pos, float(i) / steps), radius)
		_erase_circle(pos, radius)
		_prev = pos
		_texture_dirty = true
		_collision_dirty = true
	else:
		_prev = Vector2.INF
		if _collision_dirty:
			_rebuild_collision()

	if _texture_dirty:
		_texture.update(_image)
		_texture_dirty = false


func _erase_circle(center: Vector2, radius: float) -> void:
	var transparent := Color(1, 1, 1, 0)
	for y in range(maxi(0, floori(center.y - radius)), mini(terrain_size.y, ceili(center.y + radius) + 1)):
		var dy := y + 0.5 - center.y
		var half_sq := radius * radius - dy * dy
		if half_sq < 0.0:
			continue
		var half := sqrt(half_sq)
		var x0 := maxi(0, floori(center.x - half))
		var x1 := mini(terrain_size.x, ceili(center.x + half))
		if x1 > x0:
			_image.fill_rect(Rect2i(x0, y, x1 - x0, 1), transparent)


func _rebuild_collision() -> void:
	_collision_dirty = false
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(_image, 0.5)
	var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bitmap.get_size()), Params.collision_tolerance)
	var segments := PackedVector2Array()
	for polygon in polygons:
		for i in polygon.size():
			segments.append(polygon[i])
			segments.append(polygon[(i + 1) % polygon.size()])
	shape_node.disabled = segments.is_empty()
	if not segments.is_empty():
		_outline.segments = segments
