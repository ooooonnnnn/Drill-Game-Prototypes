extends Node2D
## Destructible terrain filling the bottom half of the screen.
##
## The authoritative state is a CPU-side RGBA image: alpha 1 = solid, alpha 0 =
## drilled away. It is shown by shaders/terrain.gdshader. When the player stops
## drilling (see player.gd, which switches terrain collision off while drilling):
##   1. regions no longer connected to the anchored edges (left, right, bottom)
##      are cut out of the image and become RigidBody2D debris, with mass
##      proportional to their area;
##   2. the remaining terrain's collider is rebuilt as an outline simplified by
##      Params.collision_tolerance.

const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const TERRAIN_LAYER := 2
const DEBRIS_LAYER := 4
const ERASE_MARGIN := 1.0 ## extra px erased around the player so it never starts inside solid terrain
const CELL := 4 ## connectivity is checked on a grid of CELL x CELL px cells (an approximation)
const MIN_DEBRIS_AREA := 100 ## px; smaller pieces are deleted instead of becoming debris
const DEBRIS_MASS_PER_PX := 0.001 ## times Params.debris_density
const TRANSPARENT := Color(1, 1, 1, 0)

@export var player: Node2D

var terrain_size: Vector2i

@onready var fill: ColorRect = $Fill
@onready var shape_node: CollisionShape2D = $Body/CollisionShape2D

var _image: Image
var _texture: ImageTexture
var _outline := ConcavePolygonShape2D.new()
var _prev := Vector2.INF
var _texture_dirty := false
var _collision_dirty := false

# Scratch state for the connectivity flood fill.
var _alpha := PackedByteArray()
var _labels := PackedInt32Array()
var _stack := PackedInt32Array()


func _ready() -> void:
	var screen := get_viewport_rect().size
	position = Vector2(0.0, screen.y / 2.0)
	terrain_size = Vector2i(int(screen.x), int(screen.y / 2.0))

	_image = Image.create(terrain_size.x, terrain_size.y, false, Image.FORMAT_RGBA8)
	_image.fill(Color.WHITE)
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
			_split_disconnected()
			_rebuild_collision()

	if _texture_dirty:
		_texture.update(_image)
		_texture_dirty = false


func _erase_circle(center: Vector2, radius: float) -> void:
	for y in range(maxi(0, floori(center.y - radius)), mini(terrain_size.y, ceili(center.y + radius) + 1)):
		var dy := y + 0.5 - center.y
		var half_sq := radius * radius - dy * dy
		if half_sq < 0.0:
			continue
		var half := sqrt(half_sq)
		var x0 := maxi(0, floori(center.x - half))
		var x1 := mini(terrain_size.x, ceili(center.x + half))
		if x1 > x0:
			_image.fill_rect(Rect2i(x0, y, x1 - x0, 1), TRANSPARENT)


func _rebuild_collision() -> void:
	_collision_dirty = false
	var polygons := _outline_polygons(_image, terrain_size)
	var segments := PackedVector2Array()
	for polygon in polygons:
		for i in polygon.size():
			segments.append(polygon[i])
			segments.append(polygon[(i + 1) % polygon.size()])
	shape_node.disabled = segments.is_empty()
	if not segments.is_empty():
		_outline.segments = segments


func _outline_polygons(image: Image, size: Vector2i) -> Array[PackedVector2Array]:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.5)
	return bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), Params.collision_tolerance)


# --- Debris -----------------------------------------------------------------

## Finds connected regions of solid terrain on a coarse grid; every region that
## doesn't touch the left, right or bottom edge is turned into debris.
func _split_disconnected() -> void:
	var grid := Vector2i(ceili(float(terrain_size.x) / CELL), ceili(float(terrain_size.y) / CELL))
	# A cell is solid if any pixel in it is (box-filtered downscale, alpha > 0).
	var small := _image.duplicate() as Image
	small.resize(grid.x, grid.y, Image.INTERPOLATE_TRILINEAR)
	_alpha = small.get_data()
	_labels = PackedInt32Array()
	_labels.resize(grid.x * grid.y)
	_labels.fill(-1)
	var detached: Array[PackedInt32Array] = []

	for start in grid.x * grid.y:
		if _labels[start] != -1 or _alpha[start * 4 + 3] == 0:
			continue
		var members := PackedInt32Array()
		var anchored := false
		_stack = PackedInt32Array([start])
		_labels[start] = 0
		while not _stack.is_empty():
			var cell := _stack[_stack.size() - 1]
			_stack.resize(_stack.size() - 1)
			members.append(cell)
			var x := cell % grid.x
			var y := cell / grid.x
			if x == 0 or x == grid.x - 1 or y == grid.y - 1:
				anchored = true
			if x > 0:
				_visit(cell - 1)
			if x < grid.x - 1:
				_visit(cell + 1)
			if y > 0:
				_visit(cell - grid.x)
			if y < grid.y - 1:
				_visit(cell + grid.x)
		if not anchored:
			detached.append(members)

	for members in detached:
		_spawn_debris(members, grid.x)
	if not detached.is_empty():
		_texture_dirty = true


func _visit(cell: int) -> void:
	if _labels[cell] == -1 and _alpha[cell * 4 + 3] != 0:
		_labels[cell] = 0
		_stack.append(cell)


func _spawn_debris(members: PackedInt32Array, grid_width: int) -> void:
	var image_rect := Rect2i(Vector2i.ZERO, terrain_size)
	var cell_min := Vector2i(1 << 30, 1 << 30)
	var cell_max := Vector2i(-1, -1)
	var centroid_sum := Vector2.ZERO
	for cell in members:
		var c := Vector2i(cell % grid_width, cell / grid_width)
		cell_min = cell_min.min(c)
		cell_max = cell_max.max(c)
		centroid_sum += Vector2(c * CELL) + Vector2.ONE * (CELL / 2.0)

	var bounds := Rect2i(cell_min * CELL, (cell_max - cell_min + Vector2i.ONE) * CELL).intersection(image_rect)

	# Move the region's pixels from the terrain image into its own image.
	var piece := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	for cell in members:
		var rect := Rect2i(Vector2i(cell % grid_width, cell / grid_width) * CELL, Vector2i(CELL, CELL)).intersection(image_rect)
		piece.blit_rect(_image, rect, rect.position - bounds.position)
		_image.fill_rect(rect, TRANSPARENT)

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(piece, 0.5)
	var area := bitmap.get_true_bit_count()
	if area < MIN_DEBRIS_AREA:
		return

	var body := RigidBody2D.new()
	body.position = Vector2(bounds.position)
	body.collision_layer = DEBRIS_LAYER
	body.collision_mask = TERRAIN_LAYER | DEBRIS_LAYER
	body.mass = area * Params.debris_density * DEBRIS_MASS_PER_PX
	body.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = centroid_sum / members.size() - Vector2(bounds.position)
	body.linear_damp = 1.0
	body.angular_damp = 1.0
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	# Rigid bodies need convex shapes, so each outline polygon is decomposed.
	# Holes inside a piece are therefore solid for collision (but not visually).
	for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bounds.size), Params.collision_tolerance):
		if polygon.size() < 3:
			continue
		var parts := Geometry2D.decompose_polygon_in_convex(polygon)
		if parts.is_empty():
			parts = [Geometry2D.convex_hull(polygon)]
		for part in parts:
			var convex := ConvexPolygonShape2D.new()
			convex.points = part
			var collision := CollisionShape2D.new()
			collision.shape = convex
			body.add_child(collision)
	if body.get_child_count() == 0:
		body.free()
		return

	var visual := ColorRect.new()
	visual.size = Vector2(bounds.size)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("solid_mask", ImageTexture.create_from_image(piece))
	visual.material = material
	body.add_child(visual)

	add_child(body)
