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
		await _settle_layout()
		_check_card_geometry(reveal, count)
	_check(completions == 3, "Each presentation finishes exactly once despite repeated skips")
	_check(reveal.clear() and not reveal.is_revealing(), "Clearing leaves the chest ready for a new presentation")
	_check(reveal.get_node("Results").get_child_count() == 0, "Clearing removes the previous reward display")
	_check(completions == 3, "Clearing completed results does not emit another completion")
	await _check_wrapped_title_reuse(reveal)
	if failures == 0:
		print("PASS: one/three/five reward cards and full wrapped titles fit through presentation reuse and resizing; completion is idempotent")
	quit(1 if failures > 0 else 0)


func _finished() -> void:
	completions += 1


func _settle_layout() -> void:
	# Containers propagate wrapped minimum sizes over deferred engine frames.
	for frame: int in range(6):
		await process_frame


func _check_card_geometry(reveal: ChestReveal, count: int) -> Array[Rect2]:
	var bounds := Rect2(Vector2.ZERO, reveal.size)
	var cards: Array[Node] = reveal.get_node("Results").get_children()
	var rects: Array[Rect2] = []
	_check(cards.size() == count, "Each reward has a visible result card")
	for index: int in range(cards.size()):
		var card := cards[index] as Control
		rects.append(card.get_rect())
		_check(bounds.encloses(card.get_rect()), "Result cards stay inside the reveal surface")
		_check(not card.get_rect().intersects(reveal._chest_rect()), "Reward cards do not cover the opened chest")
		for other: int in range(index + 1, cards.size()):
			_check(not card.get_rect().intersects((cards[other] as Control).get_rect()), "Result cards do not cover one another")
	return rects


func _check_title_fit(card: Control, expected_title: String) -> Label:
	var title: Label
	for candidate: Node in card.find_children("*", "Label", true, false):
		if (candidate as Label).text == expected_title:
			title = candidate as Label
			break
	_check(title != null, "The result card displays the full configured reward title")
	if title == null:
		return null
	_check(title.is_visible_in_tree() and card.modulate.a > 0.0 and title.modulate.a > 0.0, "The full reward title is visible after reveal")
	_check(title.get_theme_font_size("font_size") >= 16, "Wrapped reward titles remain readable")
	_check(title.visible_characters < 0 or title.visible_characters >= expected_title.length(), "The title does not hide trailing characters")
	_check(title.get_visible_line_count() == title.get_line_count(), "All wrapped reward title lines fit visibly")
	_check(title.size.y >= title.get_minimum_size().y, "The title has room for its shaped text height")
	_check(card.get_global_rect().encloses(title.get_global_rect()), "The full title label stays inside its reward card")
	_check((title.get_parent() as Control).get_global_rect().encloses(title.get_global_rect()), "The full title label stays inside its card content")
	return title


func _check_restored_bounds(actual: Array[Rect2], expected: Array[Rect2]) -> void:
	_check(actual.size() == expected.size(), "Returning to compact size restores every card")
	for index: int in range(mini(actual.size(), expected.size())):
		_check(actual[index].position.is_equal_approx(expected[index].position), "Returning to compact size restores card positions")
		_check(actual[index].size.is_equal_approx(expected[index].size), "Returning to compact size restores card dimensions without stale wrapped minimums")


func _check_wrapped_title_reuse(reveal: ChestReveal) -> void:
	# Duplicate a configured resource so this fixture cannot mutate the shared catalog.
	var reward: TowerReward = CollectionStore.DEFAULT_CATALOG[0].duplicate() as TowerReward
	reward.title = "Moonstone Archer"
	var rewards: Array[TowerReward] = [reward, CollectionStore.DEFAULT_CATALOG[1], CollectionStore.DEFAULT_CATALOG[2]]
	var previous_completions: int = completions
	reveal.present(rewards)
	reveal.skip()
	reveal.skip()
	await _settle_layout()
	var compact_rects: Array[Rect2] = _check_card_geometry(reveal, rewards.size())
	var cards: Array[Node] = reveal.get_node("Results").get_children()
	if cards.size() != rewards.size():
		reveal.clear()
		return
	var title := _check_title_fit(cards[0] as Control, reward.title)
	if title == null:
		reveal.clear()
		return
	var compact_lines: int = title.get_line_count()
	_check(compact_lines > 1, "The longer custom title exercises real wrapping in a compact card")
	_check(completions == previous_completions + 1, "The wrapped-title presentation finishes exactly once")

	reveal.size = Vector2(900, 600)
	await _settle_layout()
	_check_card_geometry(reveal, rewards.size())
	title = _check_title_fit(cards[0] as Control, reward.title)
	if title != null:
		_check(title.get_line_count() < compact_lines, "Widening the reveal reflows the title into fewer lines")
	_check(reveal.get_node("Results").get_children() == cards, "Resizing retains the current reward cards")

	reveal.size = Vector2(500, 410)
	await _settle_layout()
	_check_restored_bounds(_check_card_geometry(reveal, rewards.size()), compact_rects)
	title = _check_title_fit(cards[0] as Control, reward.title)
	if title != null:
		_check(title.get_line_count() == compact_lines, "Restoring compact width restores complete title wrapping")
	_check(completions == previous_completions + 1, "Resize transitions do not finish or restart the presentation")

	var single_reward: Array[TowerReward] = [CollectionStore.DEFAULT_CATALOG[0]]
	reveal.present(single_reward)
	reveal.skip()
	await _settle_layout()
	_check_card_geometry(reveal, single_reward.size())
	reveal.present(rewards)
	reveal.skip()
	reveal.skip()
	await _settle_layout()
	_check_restored_bounds(_check_card_geometry(reveal, rewards.size()), compact_rects)
	cards = reveal.get_node("Results").get_children()
	if cards.size() == rewards.size():
		title = _check_title_fit(cards[0] as Control, reward.title)
		if title != null:
			_check(title.get_line_count() == compact_lines, "Reusing the reveal after a different reward count restores full wrapped titles")
	_check(completions == previous_completions + 3, "Replacement presentations each finish once without stale lifecycle state")
	_check(reveal.clear() and not reveal.is_revealing(), "Clearing reused presentations leaves the reveal ready")
	_check(reveal.get_node("Results").get_child_count() == 0, "Clearing reused presentations removes their cards")
	_check(completions == previous_completions + 3, "Clearing reused results does not finish again")
