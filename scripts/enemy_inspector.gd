class_name EnemyInspector
extends PanelContainer

signal close_requested

@onready var health_bar: ProgressBar = %HealthBar
@onready var hp_value: Label = %HPValue
@onready var speed_value: Label = %SpeedValue
@onready var damage_value: Label = %DamageValue
@onready var _title: Label = %EnemyTitle
@onready var _description: Label = %Description


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
	speed_value.text = "%.2f" % float(enemy["speed"])
	damage_value.text = str(int(enemy["damage"]))
	show()


func _on_close_pressed() -> void:
	close_requested.emit()
