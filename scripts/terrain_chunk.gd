extends RefCounted
## One piece of destructible terrain: the static main terrain, or a rigid-body
## piece of debris. Both are handled identically.
##
## State is a CPU-side RGBA image (alpha 1 = solid, alpha 0 = drilled away),
## shown through shaders/terrain.gdshader. On top of that, a coarse grid of
## CELL x CELL px cells keeps an exact "contains any solid pixel" flag per cell;
## connectivity is checked on that grid (poll()), so no solid pixel can ever be
## left behind when a region is cut out.

const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const CELL := 4
const MIN_AREA := 100 ## px; debris smaller than this is deleted
const MASS_PER_PX := 0.001 ## times Params.debris_density
const TRANSPARENT := Color(1, 1, 1, 0)

var body: PhysicsBody2D
var size: Vector2i
var is_static: bool
var needs_poll := false ## erased since the last poll()
var empty := false ## nothing worth keeping is left; the owner should delete it
var center_of_mass := Vector2.ZERO ## local px (rigid chunks)

var _image: Image
var _texture: ImageTexture
var _texture_dirty := false
var _static_shape: CollisionShape2D # only for the static chunk
var _outline := ConcavePolygonShape2D.new()

var _grid: Vector2i
var _cell_solid := PackedByteArray()
var _cell_dirty := PackedByteArray()
var _dirty_cells := PackedInt32Array()

# Scratch state for the flood fill.
var _labels := PackedInt32Array()
var _stack := PackedInt32Array()


## solid_cells: per-cell flags for the image's grid; omit for a fully solid image.
func _init(p_body: PhysicsBody2D, visual: ColorRect, image: Image,
		solid_cells := PackedByteArray(), static_shape: CollisionShape2D = null) -> void:
	body = p_body
	_image = image
	size = image.get_size()
	is_static = static_shape != null
	_static_shape = static_shape
	if is_static:
		_static_shape.shape = _outline

	_grid = Vector2i(ceili(float(size.x) / CELL), ceili(float(size.y) / CELL))
	if solid_cells.is_empty():
		_cell_solid.resize(_grid.x * _grid.y)
		_cell_solid.fill(1)
	else:
		_cell_solid = solid_cells
	_cell_dirty.resize(_grid.x * _grid.y)

	_texture = ImageTexture.create_from_image(_image)
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("solid_mask", _texture)
	visual.material = material
	visual.size = Vector2(size)


# --- Drilling ---------------------------------------------------------------

## Erases the swept path of a disc, given in global coordinates.
func stamp_path(from_global: Vector2, to_global: Vector2, radius: float) -> void:
	var from := body.to_local(from_global)
	var to := body.to_local(to_global)
	var path_bounds := Rect2(from, Vector2.ZERO).expand(to).grow(radius)
	if not path_bounds.intersects(Rect2(Vector2.ZERO, Vector2(size))):
		return
	# Stamp along the path so fast movement leaves no gaps.
	var step := maxf(1.0, radius * 0.5)
	var steps := ceili(from.distance_to(to) / step)
	for i in range(1, steps + 1):
		_erase_circle(from.lerp(to, float(i) / steps), radius)
	_erase_circle(to, radius)


func _erase_circle(center: Vector2, radius: float) -> void:
	for y in range(maxi(0, floori(center.y - radius)), mini(size.y, ceili(center.y + radius) + 1)):
		var dy := y + 0.5 - center.y
		var half_sq := radius * radius - dy * dy
		if half_sq < 0.0:
			continue
		var half := sqrt(half_sq)
		var x0 := maxi(0, floori(center.x - half))
		var x1 := mini(size.x, ceili(center.x + half))
		if x1 > x0:
			_image.fill_rect(Rect2i(x0, y, x1 - x0, 1), TRANSPARENT)
	needs_poll = true
	_texture_dirty = true
	# Flag the cells that may have lost their last solid pixel.
	var cx0 := clampi(floori((center.x - radius) / CELL), 0, _grid.x - 1)
	var cx1 := clampi(floori((center.x + radius) / CELL), 0, _grid.x - 1)
	var cy0 := clampi(floori((center.y - radius) / CELL), 0, _grid.y - 1)
	var cy1 := clampi(floori((center.y + radius) / CELL), 0, _grid.y - 1)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var cell := cy * _grid.x + cx
			if _cell_solid[cell] != 0 and _cell_dirty[cell] == 0:
				_cell_dirty[cell] = 1
				_dirty_cells.append(cell)


func flush_texture() -> void:
	if _texture_dirty:
		_texture.update(_image)
		_texture_dirty = false


# --- Connectivity -----------------------------------------------------------

## Re-checks the cells touched since the last poll, then finds regions that have
## come apart. Returns the regions to cut out as dictionaries
## {image, origin (px, local), solid_cells}. They are already removed from this
## chunk. Static chunk: every region not touching the left, right or bottom
## edge. Rigid chunk: every region except the largest.
func poll() -> Array[Dictionary]:
	needs_poll = false
	_refresh_cells()

	var regions: Array[PackedInt32Array] = []
	var anchored: Array[bool] = []
	_find_regions(regions, anchored)
	if regions.is_empty():
		empty = true
		return []

	var keep := -1
	if not is_static:
		keep = 0
		for i in regions.size():
			if regions[i].size() > regions[keep].size():
				keep = i

	var pieces: Array[Dictionary] = []
	for i in regions.size():
		var detach := (not anchored[i]) if is_static else (i != keep)
		if detach:
			pieces.append(_extract(regions[i]))
	if not pieces.is_empty():
		_texture_dirty = true
	return pieces


func _refresh_cells() -> void:
	if _dirty_cells.is_empty():
		return
	var data := _image.get_data()
	for cell in _dirty_cells:
		_cell_dirty[cell] = 0
		var x0 := (cell % _grid.x) * CELL
		var y0 := (cell / _grid.x) * CELL
		var x1 := mini(x0 + CELL, size.x)
		var y1 := mini(y0 + CELL, size.y)
		var solid := false
		for y in range(y0, y1):
			var offset := (y * size.x + x0) * 4 + 3
			for x in x1 - x0:
				if data[offset + x * 4] != 0:
					solid = true
					break
			if solid:
				break
		_cell_solid[cell] = 1 if solid else 0
	_dirty_cells.clear()


func _find_regions(regions: Array[PackedInt32Array], anchored: Array[bool]) -> void:
	_labels.resize(_grid.x * _grid.y)
	_labels.fill(0)
	for start in _grid.x * _grid.y:
		if _labels[start] != 0 or _cell_solid[start] == 0:
			continue
		var members := PackedInt32Array()
		var touches_edge := false
		_stack = PackedInt32Array([start])
		_labels[start] = 1
		while not _stack.is_empty():
			var cell := _stack[_stack.size() - 1]
			_stack.resize(_stack.size() - 1)
			members.append(cell)
			var x := cell % _grid.x
			var y := cell / _grid.x
			if x == 0 or x == _grid.x - 1 or y == _grid.y - 1:
				touches_edge = true
			if x > 0:
				_visit(cell - 1)
			if x < _grid.x - 1:
				_visit(cell + 1)
			if y > 0:
				_visit(cell - _grid.x)
			if y < _grid.y - 1:
				_visit(cell + _grid.x)
		regions.append(members)
		anchored.append(touches_edge)


func _visit(cell: int) -> void:
	if _labels[cell] == 0 and _cell_solid[cell] != 0:
		_labels[cell] = 1
		_stack.append(cell)


## Moves a region's pixels out of this chunk into a new image.
func _extract(members: PackedInt32Array) -> Dictionary:
	var image_rect := Rect2i(Vector2i.ZERO, size)
	var cell_min := Vector2i(1 << 30, 1 << 30)
	var cell_max := Vector2i(-1, -1)
	for cell in members:
		var c := Vector2i(cell % _grid.x, cell / _grid.x)
		cell_min = cell_min.min(c)
		cell_max = cell_max.max(c)
	var bounds := Rect2i(cell_min * CELL, (cell_max - cell_min + Vector2i.ONE) * CELL).intersection(image_rect)

	var piece := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	var piece_grid := Vector2i(ceili(float(bounds.size.x) / CELL), ceili(float(bounds.size.y) / CELL))
	var piece_cells := PackedByteArray()
	piece_cells.resize(piece_grid.x * piece_grid.y)
	for cell in members:
		var c := Vector2i(cell % _grid.x, cell / _grid.x)
		var rect := Rect2i(c * CELL, Vector2i(CELL, CELL)).intersection(image_rect)
		piece.blit_rect(_image, rect, rect.position - bounds.position)
		_image.fill_rect(rect, TRANSPARENT)
		_cell_solid[cell] = 0
		var pc := c - cell_min
		piece_cells[pc.y * piece_grid.x + pc.x] = 1
	return {"image": piece, "origin": bounds.position, "solid_cells": piece_cells}


# --- Collision --------------------------------------------------------------

## Rebuilds the collider from the current image, simplified by
## Params.collision_tolerance. Rigid chunks also update their mass properties.
func rebuild_shapes() -> void:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(_image, 0.5)
	var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), Params.collision_tolerance)

	if is_static:
		# The static terrain may use concave outlines.
		var segments := PackedVector2Array()
		for polygon in polygons:
			for i in polygon.size():
				segments.append(polygon[i])
				segments.append(polygon[(i + 1) % polygon.size()])
		_static_shape.disabled = segments.is_empty()
		if not segments.is_empty():
			_outline.segments = segments
		return

	var area := bitmap.get_true_bit_count()
	if area < MIN_AREA:
		empty = true
		return

	# Rigid bodies need convex shapes, so each outline polygon is decomposed.
	# Holes inside a piece are therefore solid for collision (but not visually).
	for child in body.get_children():
		if child is CollisionShape2D:
			body.remove_child(child)
			child.queue_free()
	var shape_count := 0
	for polygon in polygons:
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
			shape_count += 1
	if shape_count == 0:
		empty = true
		return

	var rigid := body as RigidBody2D
	rigid.mass = maxf(0.01, area * Params.debris_density * MASS_PER_PX)
	_update_mass_distribution(rigid)


## Center of mass and moment of inertia from the solid cells. The inertia is set
## explicitly: Godot's automatic one measures every shape from its node origin
## (the chunk's corner here, not the shape's centroid), which inflates it
## several times over and makes debris unnaturally hard to spin.
func _update_mass_distribution(rigid: RigidBody2D) -> void:
	var centers := PackedVector2Array()
	var sum := Vector2.ZERO
	for cell in _grid.x * _grid.y:
		if _cell_solid[cell] != 0:
			var center := Vector2(Vector2i(cell % _grid.x, cell / _grid.x) * CELL) + Vector2.ONE * (CELL / 2.0)
			centers.append(center)
			sum += center
	var count := maxi(1, centers.size())
	center_of_mass = sum / count
	rigid.center_of_mass = center_of_mass

	# Each cell is a CELL x CELL square: its own inertia (side² / 6 per unit
	# mass) plus the parallel-axis term.
	var spread := 0.0
	for center in centers:
		spread += center.distance_squared_to(center_of_mass)
	rigid.inertia = rigid.mass * (spread / count + CELL * CELL / 6.0)
