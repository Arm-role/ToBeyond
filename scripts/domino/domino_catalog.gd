extends RefCounted
## Static catalog of Domino artifacts. No class_name: use
## const Catalog = preload("res://scripts/domino/domino_catalog.gd").

const DIR := "res://data/domino/artifacts/"
const BOSS_DIR := "res://data/domino/bosses/"
static var _list: Array = []
static var _defs: Dictionary = {}
static var _bosses: Array = []


static func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		f = f.trim_suffix(".remap")   # web export lists "x.tres.remap"
		if f.ends_with(".tres") or f.ends_with(".res"):
			out.append(dir + f)
	return out


static func _ensure() -> void:
	if not _list.is_empty():
		return
	for path in _files(DIR):
		var d: Resource = load(path)
		if d != null and d.get("id") != null and d.id != "":
			_defs[d.id] = d
			_list.append(d)
	_list.sort_custom(func(a, b): return a.catalog_order < b.catalog_order)


static func all() -> Array:
	_ensure()
	return _list


static func get_def(id: String) -> Resource:
	_ensure()
	return _defs.get(id)


static func bosses() -> Array:
	if _bosses.is_empty():
		for path in _files(BOSS_DIR):
			var d: Resource = load(path)
			if d != null and d.get("id") != null and d.id != "":
				_bosses.append(d)
		_bosses.sort_custom(func(a, b): return a.catalog_order < b.catalog_order)
	return _bosses


static func get_boss(id: String) -> Resource:
	for b in bosses():
		if b.id == id:
			return b
	return null
