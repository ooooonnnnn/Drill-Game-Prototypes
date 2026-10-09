extends Node
## Autoload "Params": tweakable values shared by the game and the menu.

signal changed

# name -> [default, min, max, step, label]
const DEFS := {
	"size_fraction": [0.05, 0.01, 0.2, 0.005, "Diameter (fraction of screen width)"],
	"player_mass": [50.0, 1.0, 500.0, 1.0, "Mass"],
	"spring_radius": [150.0, 10.0, 600.0, 1.0, "Spring radius (px from cursor; spring inside, full accel outside)"],
	"max_accel": [3000.0, 100.0, 10000.0, 10.0, "Max acceleration (px/s²)"],
	"max_speed": [1500.0, 100.0, 5000.0, 10.0, "Max speed outside radius (px/s)"],
	"max_speed_inside": [600.0, 10.0, 5000.0, 10.0, "Max speed inside radius (px/s)"],
	"turn_speed": [10.0, 0.5, 40.0, 0.5, "Turn speed (rad/s)"],
	"collision_tolerance": [2.0, 0.5, 10.0, 0.1, "Collision tolerance (px; higher = coarser, faster)"],
	"split_interval": [0.25, 0.05, 2.0, 0.05, "Disconnect check interval while drilling (s)"],
	"debris_density": [1.0, 0.1, 20.0, 0.1, "Debris density (mass per 1000 px²)"],
	"hook_launch_speed": [1500.0, 100.0, 5000.0, 10.0, "Launch speed (px/s)"],
	"hook_timeout": [0.6, 0.05, 3.0, 0.05, "Miss timeout (s)"],
	"hook_retract_speed": [2000.0, 100.0, 6000.0, 10.0, "Retract speed (px/s)"],
	"hook_reel_speed": [400.0, 10.0, 3000.0, 10.0, "Reel speed (px/s)"],
}

# Menu sections, in display order: [title, [keys...]]
const CATEGORIES := [
	["Player", ["size_fraction", "player_mass"]],
	["Movement", ["spring_radius", "max_accel", "max_speed", "max_speed_inside"]],
	["Turning", ["turn_speed"]],
	["Terrain", ["collision_tolerance", "split_interval", "debris_density"]],
	["Grappling hook", ["hook_launch_speed", "hook_timeout", "hook_retract_speed", "hook_reel_speed"]],
]

var size_fraction: float
var player_mass: float
var spring_radius: float
var max_accel: float
var max_speed: float
var max_speed_inside: float
var turn_speed: float
var collision_tolerance: float
var split_interval: float
var debris_density: float
var hook_launch_speed: float
var hook_timeout: float
var hook_retract_speed: float
var hook_reel_speed: float


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	for key in DEFS:
		set(key, DEFS[key][0])
	changed.emit()


func set_param(key: String, value: float) -> void:
	set(key, value)
	changed.emit()
