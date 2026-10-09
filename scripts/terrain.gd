extends Node2D
## Destructible terrain: a white rectangle whose pixels become transparent
## wherever the player has touched. The touched pixels are accumulated in a
## SubViewport that is never cleared (see terrain_brush.gd) and used as a mask
## by shaders/terrain.gdshader.

@export var player: Node2D
@export var terrain_size := Vector2(1120, 560)

@onready var mask_viewport: SubViewport = $MaskViewport
@onready var brush: Node2D = $MaskViewport/Brush
@onready var fill: ColorRect = $Fill


func _ready() -> void:
	mask_viewport.size = Vector2i(terrain_size)
	fill.size = terrain_size
	(fill.material as ShaderMaterial).set_shader_parameter("erase_mask", mask_viewport.get_texture())
	brush.terrain = self
	brush.player = player
