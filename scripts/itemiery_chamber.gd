class_name ItemieryChamber
extends Node2D
## Static native-pixel shelf room with independent, visibility-gated accents.

const SLOT_COLUMNS: int = 6
const SLOT_ROWS: int = 5
const SLOT_COUNT: int = SLOT_COLUMNS * SLOT_ROWS
const ROOM_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/itemiery/common_room.png"),
	preload("res://assets/ui/itemiery/uncommon_room.png"),
	preload("res://assets/ui/itemiery/rare_room.png"),
	preload("res://assets/ui/itemiery/epic_room.png"),
	preload("res://assets/ui/itemiery/mythic_room.png"),
	preload("res://assets/ui/itemiery/legendary_room.png"),
	preload("res://assets/ui/itemiery/orcfeccion_room.png"),
]

var _active: bool = false
var _background: Sprite2D = Sprite2D.new()
var _effects := preload("res://scripts/itemiery_chamber_effects.gd").new()


static func slot_rect(index: int) -> Rect2:
	@warning_ignore("integer_division")
	var row: int = index / SLOT_COLUMNS
	return Rect2(83 + (index % SLOT_COLUMNS) * 82, 58 + row * 44, 64, 36)


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.name = "RoomBackground"
	_background.centered = false
	_background.texture = ROOM_TEXTURES[ItemRarity.Tier.COMMON]
	add_child(_background)
	_effects.name = "ChamberEffects"
	add_child(_effects)
	set_process(false)


func _ready() -> void:
	_sync_effects()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_instance_valid(_effects):
		_sync_effects()


func configure(tier: ItemRarity.Tier) -> void:
	_background.texture = ROOM_TEXTURES[int(tier)]
	_effects.configure(tier)
	_sync_effects()


func set_active(active: bool) -> void:
	_active = active
	_sync_effects()


func _sync_effects() -> void:
	_effects.set_active(_active and is_inside_tree() and is_visible_in_tree())
