extends RefCounted

## Content IDs are "<namespace>:<entry>" strings, e.g. "base:reload". The
## category is not part of the string: every field that holds an ID has one
## category, and ModelDb is keyed by category. No class_name — preload.

const SEPARATOR := ":"
const BASE := "base"


static func make(ns: String, entry: String) -> String:
	return ns + SEPARATOR + entry


static func is_full(id: String) -> bool:
	return id.contains(SEPARATOR)


static func namespace_of(id: String) -> String:
	return id.get_slice(SEPARATOR, 0) if is_full(id) else ""


static func entry_of(id: String) -> String:
	return id.substr(id.find(SEPARATOR) + 1) if is_full(id) else id


## The token used in translation keys and asset file names. Base content keeps
## its bare entry (existing keys and paths stay valid); other namespaces prefix
## theirs so two mods cannot share a key.
static func key_entry(id: String) -> String:
	var ns := namespace_of(id)
	if ns == "" or ns == BASE:
		return entry_of(id)
	return ns + "_" + entry_of(id)
