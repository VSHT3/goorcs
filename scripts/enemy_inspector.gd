class_name EnemyInspector
extends PanelContainer

signal close_requested

@onready var health_bar: ProgressBar = %HealthBar
@onready var hp_value: Label = %HPValue
@onready var speed_value: Label = %SpeedValue
@onready var damage_value: Label = %DamageValue
@onready var _title: Label = %EnemyTitle
@onready var _description: Label = %Description
var _shield_value: Label
var _stun_value: Label


func _ready() -> void:
	CloseButtonStyle.apply(%CloseButton)
	_shield_value = Label.new()
	_shield_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_value.add_theme_color_override("font_color", Color("ead58c"))
	health_bar.get_parent().add_child(_shield_value)
	health_bar.get_parent().move_child(_shield_value, health_bar.get_index() + 1)
	_stun_value = Label.new()
	_stun_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stun_value.add_theme_color_override("font_color", Color("ead58c"))
	health_bar.get_parent().add_child(_stun_value)
	health_bar.get_parent().move_child(_stun_value, _shield_value.get_index() + 1)


func refresh(enemy: Dictionary, type_stats: Dictionary) -> void:
	if enemy.is_empty():
		hide()
		return

	_title.text = String(type_stats["title"])
	_description.text = String(type_stats["description"]).strip_edges()
	_description.visible = not _description.text.is_empty()
	health_bar.max_value = float(enemy["max_hp"])
	health_bar.value = float(enemy["hp"])
	hp_value.text = str(int(enemy["hp"]))
	var shield_max: int = int(enemy.get("shield_max_hits", 0))
	_shield_value.visible = shield_max > 0
	_shield_value.text = "Shield %d / %d" % [int(enemy.get("shield_hits", 0)), shield_max]
	var stunned: float = float(enemy.get("stunned_remaining", 0.0))
	_stun_value.visible = stunned > 0.0
	_stun_value.text = "Stunned %.1fs" % stunned
	var speed: float = float(enemy["speed"])
	speed_value.text = "%.2f" % speed
	damage_value.text = str(int(enemy["damage"]))
	show()


func _on_close_pressed() -> void:
	close_requested.emit()
