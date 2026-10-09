extends Node2D
## Lives inside the mask SubViewport (which never clears). Each frame it draws
## the player's footprint, plus a swept line from the previous position so fast
## movement leaves no gaps. Drawn pixels accumulate in the mask.

var terrain: Node2D
var player: Node2D
var _prev := Vector2.INF


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if terrain == null or player == null:
		return
	var pos := terrain.to_local(player.global_position)
	var radius: float = player.get("radius")
	if _prev == Vector2.INF:
		_prev = pos
	draw_line(_prev, pos, Color.WHITE, radius * 2.0)
	draw_circle(_prev, radius, Color.WHITE)
	draw_circle(pos, radius, Color.WHITE)
	_prev = pos
