extends Node2D
## Destructible terrain filling the bottom half of the screen.
##
## The player drills it (while holding the left mouse button) by erasing pixels
## from every TerrainChunk. Every Params.split_interval seconds while drilling,
## and immediately when drilling stops, dirty chunks are polled: regions that
## have come apart become new RigidBody2D debris chunks, and colliders are
## rebuilt. Debris is drilled exactly like the main terrain.

const Chunk := preload("res://scripts/terrain_chunk.gd")
const MassLabel := preload("res://scripts/mass_label.gd")
const TERRAIN_LAYER := 2
const DEBRIS_LAYER := 4
const ERASE_MARGIN := 1.0 ## extra px erased around the player so it never starts inside solid terrain

@export var player: Node2D

var terrain_size: Vector2i

@onready var fill: ColorRect = $Fill
@onready var body: StaticBody2D = $Body
@onready var shape_node: CollisionShape2D = $Body/CollisionShape2D

var _main
var _chunks := []
var _prev := Vector2.INF # previous player position (global)
var _poll_timer := 0.0


func _ready() -> void:
	var screen := get_viewport_rect().size
	position = Vector2(0.0, screen.y / 2.0)
	terrain_size = Vector2i(int(screen.x), int(screen.y / 2.0))

	var image := Image.create(terrain_size.x, terrain_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_main = Chunk.new(body, fill, image, PackedByteArray(), shape_node)
	_chunks.append(_main)
	_main.rebuild_shapes()


func _physics_process(delta: float) -> void:
	var drilling: bool = player.is_drilling()
	var due := not drilling
	if drilling:
		var pos := player.global_position
		var radius: float = player.radius + ERASE_MARGIN
		var from := pos if _prev == Vector2.INF else _prev
		for chunk in _chunks:
			chunk.stamp_path(from, pos, radius)
		_prev = pos
		_poll_timer += delta
		if _poll_timer >= Params.split_interval:
			_poll_timer = 0.0
			due = true
	else:
		_prev = Vector2.INF
		_poll_timer = 0.0

	if due:
		_poll_dirty_chunks()
	for chunk in _chunks:
		chunk.flush_texture()


func _poll_dirty_chunks() -> void:
	var dirty := _chunks.filter(func(chunk): return chunk.needs_poll)
	if dirty.is_empty():
		return

	var spawned := []
	var origins := []
	for chunk in dirty:
		for piece in chunk.poll():
			var parent_state := _kinematics(chunk)
			var new_chunk = _spawn_debris(chunk, piece)
			spawned.append(new_chunk)
			origins.append(parent_state)

	for chunk in dirty:
		if not chunk.empty:
			chunk.rebuild_shapes()
	for i in spawned.size():
		var chunk = spawned[i]
		chunk.rebuild_shapes()
		if not chunk.empty:
			_inherit_velocity(chunk, origins[i])

	for chunk in dirty + spawned:
		if chunk.empty and chunk != _main:
			_chunks.erase(chunk)
			chunk.body.get_parent().remove_child(chunk.body)
			chunk.body.queue_free()


func _spawn_debris(parent, piece: Dictionary):
	var debris := RigidBody2D.new()
	debris.collision_layer = DEBRIS_LAYER
	debris.collision_mask = TERRAIN_LAYER | DEBRIS_LAYER
	debris.linear_damp = Params.debris_linear_damp
	debris.angular_damp = 1.0
	debris.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	debris.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	# Same orientation as the chunk it came from, so it appears exactly in place.
	debris.transform = parent.body.transform * Transform2D(0.0, Vector2(piece["origin"]))

	var visual := ColorRect.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debris.add_child(visual)
	debris.add_child(MassLabel.new())
	add_child(debris)

	var chunk = Chunk.new(debris, visual, piece["image"], piece["solid_cells"])
	_chunks.append(chunk)
	return chunk


## State of a chunk's body at the moment a piece is cut from it.
func _kinematics(chunk) -> Dictionary:
	var state := {"transform": chunk.body.transform, "com": Vector2.ZERO, "linear": Vector2.ZERO, "angular": 0.0}
	if not chunk.is_static:
		var rigid := chunk.body as RigidBody2D
		state["com"] = chunk.center_of_mass
		state["linear"] = rigid.linear_velocity
		state["angular"] = rigid.angular_velocity
	return state


## The new piece keeps moving as the part of the parent it was.
func _inherit_velocity(chunk, parent_state: Dictionary) -> void:
	var rigid := chunk.body as RigidBody2D
	var offset: Vector2 = rigid.transform * chunk.center_of_mass \
			- parent_state["transform"] * parent_state["com"]
	var angular: float = parent_state["angular"]
	rigid.linear_velocity = parent_state["linear"] + angular * Vector2(-offset.y, offset.x)
	rigid.angular_velocity = angular
