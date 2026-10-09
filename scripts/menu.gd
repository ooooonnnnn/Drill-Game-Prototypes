extends CanvasLayer
## Parameter menu: one slider per entry in Params.DEFS, plus Restart / Reset.
## Esc toggles visibility.

@onready var panel: PanelContainer = $Panel
@onready var rows: VBoxContainer = $Panel/Margin/VBox/Rows
@onready var restart_button: Button = $Panel/Margin/VBox/Buttons/Restart
@onready var defaults_button: Button = $Panel/Margin/VBox/Buttons/Defaults

var _sliders := {}


func _ready() -> void:
	for key in Params.DEFS:
		_add_row(key)
	restart_button.pressed.connect(func(): Params.restart_requested.emit())
	defaults_button.pressed.connect(_on_defaults)


func _add_row(key: String) -> void:
	var def: Array = Params.DEFS[key]
	var label := Label.new()
	rows.add_child(label)
	var slider := HSlider.new()
	slider.min_value = def[1]
	slider.max_value = def[2]
	slider.step = def[3]
	slider.value = Params.get(key)
	slider.custom_minimum_size.x = 320
	slider.focus_mode = Control.FOCUS_NONE
	rows.add_child(slider)
	_sliders[key] = slider
	var update_label := func(value: float): label.text = "%s: %s" % [def[4], str(snappedf(value, def[3]))]
	update_label.call(slider.value)
	slider.value_changed.connect(func(value: float):
		update_label.call(value)
		Params.set_param(key, value))


func _on_defaults() -> void:
	Params.reset_defaults()
	for key in _sliders:
		_sliders[key].value = Params.get(key)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		panel.visible = not panel.visible
