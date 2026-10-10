extends Node2D
## Game scene. Esc returns to the parameter menu. The camera follows the player,
## lerping towards it at Params.camera_follow_rate (1/s), independent of the
## frame rate. The bottom of the screen shows the impulse of the enemy's latest
## hit.

const Enemy := preload("res://scripts/enemy.gd")

@onready var player: Node2D = $Player
@onready var camera: Camera2D = $Camera
@onready var enemy: Enemy = $Enemy
@onready var impulse_label: Label = $Hud/ImpulseLabel


func _ready() -> void:
	enemy.impacted.connect(_on_enemy_impacted)
	camera.global_position = player.global_position


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): # destroyed: the camera stays where it is
		return
	var weight := 1.0 - exp(-Params.camera_follow_rate * delta)
	camera.global_position = camera.global_position.lerp(player.global_position, weight)


func _on_enemy_impacted(impulse: float) -> void:
	var result := "destroyed" if impulse > Params.enemy_break_impulse else "survived"
	impulse_label.text = "Enemy hit: impulse %.0f / break at %.0f (%s)" \
			% [impulse, Params.enemy_break_impulse, result]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
