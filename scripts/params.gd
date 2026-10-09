extends Node
## Autoload "Params": tweakable values shared by the game and the menu.

signal changed

# name -> [default, min, max, step, label]
const DEFS := {
	"size_fraction": [0.05, 0.01, 0.2, 0.005, "Diameter (fraction of screen width)"],
	"player_mass": [50.0, 1.0, 500.0, 1.0, "Mass"],
	"stiffness": [8.0, 0.5, 40.0, 0.1, "Stiffness (accel per px from cursor, 1/s²)"],
	"damping_ratio": [1.0, 0.1, 2.0, 0.01, "Damping ratio (1 = critical)"],
	"max_accel": [3000.0, 100.0, 10000.0, 10.0, "Max acceleration (px/s²)"],
	"max_speed": [1500.0, 100.0, 5000.0, 10.0, "Max speed (px/s)"],
	"turn_threshold": [60.0, 0.0, 400.0, 1.0, "Turn threshold (px from cursor)"],
	"turn_speed": [10.0, 0.5, 40.0, 0.5, "Turn speed (rad/s)"],
	"collision_tolerance": [2.0, 0.5, 10.0, 0.1, "Collision tolerance (px; higher = coarser, faster)"],
	"split_interval": [0.25, 0.05, 2.0, 0.05, "Disconnect check interval while drilling (s)"],
	"debris_density": [1.0, 0.1, 20.0, 0.1, "Debris density (mass per 1000 px²)"],
}

# Menu sections, in display order: [title, [keys...]]
const CATEGORIES := [
	["Player", ["size_fraction", "player_mass"]],
	["Movement", ["stiffness", "damping_ratio", "max_accel", "max_speed"]],
	["Turning", ["turn_threshold", "turn_speed"]],
	["Terrain", ["collision_tolerance", "split_interval", "debris_density"]],
]

var size_fraction: float
var player_mass: float
var stiffness: float
var damping_ratio: float
var max_accel: float
var max_speed: float
var turn_threshold: float
var turn_speed: float
var collision_tolerance: float
var split_interval: float
var debris_density: float


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	for key in DEFS:
		set(key, DEFS[key][0])
	changed.emit()


func set_param(key: String, value: float) -> void:
	set(key, value)
	changed.emit()
