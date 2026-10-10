extends Node
## Autoload "Params": tweakable values shared by the game and the menu. Values
## saved with save_settings() are loaded again on the next launch.

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "params"

# name -> [default, min, max, step, label]
const DEFS := {
	"size_fraction": [0.02, 0.005, 0.1, 0.005, "Diameter (fraction of screen width)"],
	"player_mass": [50.0, 1.0, 500.0, 1.0, "Mass"],
	"spring_radius": [300.0, 10.0, 600.0, 1.0, "Spring radius (px from cursor; spring inside, full accel outside)"],
	"max_accel": [1500.0, 100.0, 10000.0, 10.0, "Max acceleration (px/s²)"],
	"max_speed": [750.0, 100.0, 5000.0, 10.0, "Max speed outside radius (px/s)"],
	"max_speed_inside": [300.0, 10.0, 5000.0, 10.0, "Max speed inside radius (px/s)"],
	"turn_speed": [10.0, 0.5, 40.0, 0.5, "Turn speed (rad/s)"],
	"collision_tolerance": [2.0, 0.5, 10.0, 0.1, "Collision tolerance (px; higher = coarser, faster)"],
	"split_interval": [0.25, 0.05, 2.0, 0.05, "Disconnect check interval while drilling (s)"],
	"debris_density": [1.0, 0.1, 20.0, 0.1, "Debris density (mass per 1000 px²)"],
	"debris_linear_damp": [0.1, 0.0, 1, 0.05, "Debris linear damping (1/s)"],
	"hook_launch_speed": [990.0, 100.0, 5000.0, 10.0, "Launch speed (px/s)"],
	"hook_timeout": [1.5, 0.05, 3.0, 0.05, "Miss timeout (s)"],
	"hook_retract_speed": [2000.0, 100.0, 6000.0, 10.0, "Retract speed (px/s)"],
	"hook_reel_speed": [400.0, 10.0, 3000.0, 10.0, "Reel speed (px/s)"],
	"enemy_mass": [50.0, 1.0, 500.0, 1.0, "Mass"],
	"enemy_max_accel": [200.0, 10.0, 10000.0, 10.0, "Max acceleration (px/s²)"],
	"enemy_max_speed": [100.0, 10.0, 500.0, 10.0, "Max speed (px/s)"],
	"enemy_knockback": [800.0, 0.0, 5000.0, 10.0, "Knockback (separation speed on contact, px/s)"],
	"camera_follow_rate": [6.0, 0.1, 30.0, 0.1, "Follow rate (1/s; the gap shrinks by a factor e every 1/rate seconds)"],
	"enemy_break_impulse": [30000.0, 0.0, 200000.0, 500.0, "Break impulse (collision impulse that destroys it, mass·px/s)"],
}

# Menu sections, in display order: [title, [keys...]]
const CATEGORIES := [
	["Player", ["size_fraction", "player_mass"]],
	["Movement", ["spring_radius", "max_accel", "max_speed", "max_speed_inside"]],
	["Turning", ["turn_speed"]],
	["Terrain", ["collision_tolerance", "split_interval", "debris_density", "debris_linear_damp"]],
	["Grappling hook", ["hook_launch_speed", "hook_timeout", "hook_retract_speed", "hook_reel_speed"]],
	["Enemy", ["enemy_mass", "enemy_max_accel", "enemy_max_speed", "enemy_knockback", "enemy_break_impulse"]],
	["Camera", ["camera_follow_rate"]],
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
var debris_linear_damp: float
var hook_launch_speed: float
var hook_timeout: float
var hook_retract_speed: float
var hook_reel_speed: float
var enemy_mass: float
var enemy_max_accel: float
var enemy_max_speed: float
var enemy_knockback: float
var enemy_break_impulse: float
var camera_follow_rate: float


func _init() -> void:
	reset_defaults()
	_load_settings()


func reset_defaults() -> void:
	for key in DEFS:
		set(key, DEFS[key][0])
	changed.emit()


func set_param(key: String, value: float) -> void:
	set(key, value)
	changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in DEFS:
		config.set_value(SETTINGS_SECTION, key, get(key))
	config.save(SETTINGS_PATH)


## Keys no longer in DEFS are ignored, and missing ones keep their defaults.
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key in DEFS:
		if config.has_section_key(SETTINGS_SECTION, key):
			set(key, float(config.get_value(SETTINGS_SECTION, key)))
	changed.emit()
