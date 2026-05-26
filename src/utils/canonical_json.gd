## Canonical Json
##
## Serializes JSON-safe values with sorted dictionary keys so hashes are stable
## across peers and repeated runs.
class_name CanonicalJson
extends RefCounted


## Serializes [param value] to JSON with dictionary keys sorted at every level.
static func stringify(value: Variant) -> String:
	if value is Dictionary:
		return _stringify_dictionary(value as Dictionary)
	if value is Array:
		return _stringify_array(value as Array)
	return JSON.stringify(value)


## Returns the SHA-256 hash of [param value]'s canonical JSON representation.
static func hash(value: Variant) -> String:
	return stringify(value).sha256_text()


static func _stringify_dictionary(value: Dictionary) -> String:
	var keys: Array = value.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in keys:
		parts.append("%s:%s" % [JSON.stringify(key), stringify(value[key])])
	return "{" + ",".join(parts) + "}"


static func _stringify_array(value: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: Variant in value:
		parts.append(stringify(item))
	return "[" + ",".join(parts) + "]"