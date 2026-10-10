extends Node2D
## Game scene. Esc returns to the parameter menu. The bottom of the screen shows
## the impulse of the enemy's latest hit.

const Enemy := preload("res://scripts/enemy.gd")

@onready var enemy: Enemy = $Enemy
@onready var impulse_label: Label = $Hud/ImpulseLabel


func _ready() -> void:
	enemy.impacted.connect(_on_enemy_impacted)


func _on_enemy_impacted(impulse: float) -> void:
	var result := "destroyed" if impulse > Params.enemy_break_impulse else "survived"
	impulse_label.text = "Enemy hit: impulse %.0f / break at %.0f (%s)" \
			% [impulse, Params.enemy_break_impulse, result]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
