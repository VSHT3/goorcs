class_name CombatSnapshotCodec
extends RefCounted
## Every frame is independently decodable against its reliable control baseline.
## No frame depends on another combat frame; superseded frames can be skipped.

const MAX_DECODED_BYTES: int = 32 * 1024 * 1024


static func encode_combat(state: Dictionary, baseline: Dictionary = {}) -> PackedByteArray:
	return _encode(_pack_combat(state, baseline))


static func decode_combat(packet: PackedByteArray, baseline: Dictionary = {}) -> Dictionary:
	return _unpack_combat(_decode(packet), baseline)


static func encode_snapshot(snapshot: Dictionary) -> PackedByteArray:
	var wire: Dictionary = snapshot.duplicate()
	wire["combat"] = _pack_combat(snapshot["combat"])
	return _encode(wire)


static func decode_snapshot(packet: PackedByteArray) -> Dictionary:
	var wire: Dictionary = _decode(packet)
	if wire.is_empty():
		return {}
	wire["combat"] = _unpack_combat(wire["combat"])
	return wire


static func _pack_combat(state: Dictionary, baseline: Dictionary = {}) -> Dictionary:
	var wire: Dictionary = state.duplicate()
	var routes: Array = []
	var route_indices: Dictionary = {}
	for kind: String in ["enemies", "towers"]:
		var boards: Array = [[], []]
		for slot: int in range(2):
			var originals: Dictionary = _by_id(baseline.get(kind, [[], []])[slot])
			for entity: Dictionary in state[kind][slot]:
				var original: Dictionary = originals.get(entity["id"], {})
				var record: Dictionary = {"id": entity["id"]}
				for key: String in entity:
					if key != "id" and (not original.has(key) or entity[key] != original[key]):
						record[key] = entity[key]
				if record.has("route"):
					var route: Array = record["route"]
					if not route_indices.has(route):
						route_indices[route] = routes.size()
						routes.append(route)
					record["route"] = route_indices[route]
				boards[slot].append(record)
		wire[kind] = boards
	return {"state": wire, "routes": routes, "delta": not baseline.is_empty()}


static func _unpack_combat(wire: Dictionary, baseline: Dictionary = {}) -> Dictionary:
	if wire.is_empty():
		return {}
	var state: Dictionary = wire["state"]
	var routes: Array = wire["routes"]
	for kind: String in ["enemies", "towers"]:
		for slot: int in range(2):
			var originals: Dictionary = _by_id(baseline.get(kind, [[], []])[slot]) if wire["delta"] else {}
			var entities: Array = state[kind][slot]
			for index: int in range(entities.size()):
				var record: Dictionary = entities[index]
				if record.has("route"):
					record["route"] = routes[int(record["route"])]
				var restored: Dictionary = originals.get(record["id"], {}).duplicate()
				restored.merge(record, true)
				entities[index] = restored
	return state


static func _by_id(entities: Array) -> Dictionary:
	var result: Dictionary = {}
	for entity: Dictionary in entities:
		result[entity["id"]] = entity
	return result


static func _encode(value: Dictionary) -> PackedByteArray:
	var raw: PackedByteArray = var_to_bytes(value)
	var packet := PackedByteArray()
	packet.resize(4)
	packet.encode_u32(0, raw.size())
	packet.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return packet


static func _decode(packet: PackedByteArray) -> Dictionary:
	if packet.size() <= 4:
		return {}
	var size: int = packet.decode_u32(0)
	if size <= 0 or size > MAX_DECODED_BYTES:
		return {}
	var raw: PackedByteArray = packet.slice(4).decompress(size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != size:
		return {}
	var value: Variant = bytes_to_var(raw)
	return value if value is Dictionary else {}
