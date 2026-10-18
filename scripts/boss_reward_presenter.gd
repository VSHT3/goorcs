class_name BossRewardPresenter
extends RefCounted
## Scene-local history cursor for accepted rewards; it never awards or rolls anything.

var _match_id: String = ""
var _slot: int = -1
var _seen: Dictionary[int, bool] = {}
var _pending: Array[Dictionary] = []


func observe(snapshot: Dictionary, local_slot: int) -> bool:
	var match_id: String = String(snapshot.get("statistics_id", ""))
	var changed: bool = match_id != _match_id or local_slot != _slot
	if changed:
		clear()
		_match_id = match_id
		_slot = local_slot
	if match_id.is_empty() or bool(snapshot.get("rules", {}).get("sandbox_mode", false)):
		return changed
	var rewards: Array = snapshot.get("boss_rewards", [[], []])
	if local_slot < 0 or local_slot >= rewards.size():
		return changed
	for award: Dictionary in rewards[local_slot]:
		var id: int = int(award["id"])
		if _seen.has(id):
			continue
		_seen[id] = true
		_pending.append(award.duplicate(true))
	return changed


func pending_count() -> int:
	return _pending.size()


func next_boss_id() -> StringName:
	return StringName(_pending[0]["boss_id"]) if not _pending.is_empty() else &""


func present_next(reel: RarityReel, artwork: Texture2D = null) -> bool:
	if _pending.is_empty() or reel.is_busy():
		return false
	reel.present_reward(_pending[0], artwork)
	if not reel.is_busy():
		return false
	_pending.pop_front()
	return true


func clear() -> void:
	_match_id = ""
	_slot = -1
	_seen.clear()
	_pending.clear()
