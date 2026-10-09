extends Control
## Parameter menu screen: sliders grouped by Params.CATEGORIES.
## "Restart" opens the game scene with the current parameters.

const GAME_SCENE := "res://scenes/game.tscn"
const LABEL_WIDTH := 380
const SLIDER_WIDTH := 300
const VALUE_WIDTH := 64
const HEADER_COLOR := Color("e0a526")

@onready var rows: VBoxContainer = $Center/VBox/Rows
@onready var restart_button: Button = $Center/VBox/Buttons/Restart
@onready var defaults_button: Button = $Center/VBox/Buttons/Defaults

var _sliders := {}


func _ready() -> void:
	for category in Params.CATEGORIES:
		_add_header(category[0])
		for key in category[1]:
			_add_row(key)
	restart_button.pressed.connect(func(): get_tree().change_scene_to_file(GAME_SCENE))
	defaults_button.pressed.connect(_on_defaults)


func _add_header(title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	rows.add_child(spacer)
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	rows.add_child(header)
	rows.add_child(HSeparator.new())


func _add_row(key: String) -> void:
	var def: Array = Params.DEFS[key]
	var row := HBoxContainer.new()
	rows.add_child(row)

	var label := Label.new()
	label.text = def[4]
	label.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = def[1]
	slider.max_value = def[2]
	slider.step = def[3]
	slider.value = Params.get(key)
	slider.custom_minimum_size.x = SLIDER_WIDTH
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	_sliders[key] = slider

	var value_label := Label.new()
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	var update_label := func(value: float): value_label.text = str(snappedf(value, def[3]))
	update_label.call(slider.value)
	slider.value_changed.connect(func(value: float):
		update_label.call(value)
		Params.set_param(key, value))


func _on_defaults() -> void:
	Params.reset_defaults()
	for key in _sliders:
		_sliders[key].value = Params.get(key)
