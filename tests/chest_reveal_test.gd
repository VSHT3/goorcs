extends SceneTree

var failures: int = 0
var completions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1


func _run() -> void:
	var reveal: ChestReveal = load("res://scenes/chest_reveal.tscn").instantiate()
	root.add_child(reveal)
	reveal.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	reveal.custom_minimum_size = Vector2(500, 410)
	reveal.size = Vector2(500, 410)
	reveal.finished.connect(_finished)
	await process_frame
	for count: int in [1, 3, 5]:
		var rewards: Array[TowerReward] = []
		for index: int in range(count):
			rewards.append(CollectionStore.DEFAULT_CATALOG[index % CollectionStore.DEFAULT_CATALOG.size()])
		reveal.present(rewards)
		reveal.skip()
		reveal.skip()
		await process_frame
		await process_frame
		await process_frame
		var bounds := Rect2(Vector2.ZERO, reveal.size)
		var cards: Array[Node] = reveal.get_node("Results").get_children()
		_check(cards.size() == count, "Each reward has a visible result card")
		for index: int in range(cards.size()):
			var card := cards[index] as Control
			_check(bounds.encloses(card.get_rect()), "Result cards stay inside the reveal surface")
			_check(not card.get_rect().intersects(reveal._chest_rect()), "Reward cards do not cover the opened chest")
			for other: int in range(index + 1, cards.size()):
				_check(not card.get_rect().intersects((cards[other] as Control).get_rect()), "Result cards do not cover one another")
	_check(completions == 3, "Each presentation finishes exactly once despite repeated skips")
	_check(reveal.clear() and not reveal.is_revealing(), "Clearing leaves the chest ready for a new presentation")
	_check(reveal.get_node("Results").get_child_count() == 0, "Clearing removes the previous reward display")
	_check(completions == 3, "Clearing completed results does not emit another completion")
	if failures == 0:
		print("PASS: one/three/five reward cards fit without overlap; completion is idempotent")
	quit(1 if failures > 0 else 0)


func _finished() -> void:
	completions += 1
