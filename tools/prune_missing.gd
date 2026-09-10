@tool
extends SceneTree
## Remove sources whose art is gone, so the tileset loads again.
##
##   godot --headless --path . --script res://tools/prune_missing.gd
##
## Deleting or renaming a PNG outside the FileSystem dock leaves the TileSet
## pointing at a path that is not there. Godot then refuses to load the whole
## resource, every layer that uses it loses its tiles, and one missing file
## reads as eight errors about scenes that are perfectly fine.
##
## This works on the file as text rather than loading it, because a tileset in
## that state cannot be loaded — which is exactly when you need it. It prints
## what it would remove and changes nothing unless you pass --apply.

const TILESET := "res://resources/tileset.tres"


func _init() -> void:
	var apply := "--apply" in OS.get_cmdline_user_args()
	var text := _read(TILESET)
	if text.is_empty():
		push_error("could not read %s" % TILESET)
		quit(1)
		return

	var lines := text.split("\n")
	var lost := _missing_resource_ids(lines)
	if lost.is_empty():
		print("Every texture the tileset asks for is present.")
		quit(0)
		return

	print("Missing art:")
	for path in lost.values():
		print("  %s" % path)

	var kept := _without(lines, lost.keys())
	print("%d lines removed, %d kept" % [lines.size() - kept.size(), kept.size()])
	if not apply:
		print("\nNothing written. Re-run with -- --apply to remove them.")
		quit(0)
		return

	var out := FileAccess.open(ProjectSettings.globalize_path(TILESET), FileAccess.WRITE)
	if out == null:
		push_error("could not write %s" % TILESET)
		quit(1)
		return
	out.store_string("\n".join(kept))
	out.close()
	print("\nWritten. Re-run apply_tile_roles.gd, then reopen the project.")
	quit(0)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


## External resource ids whose file is not on disk, keyed by id.
func _missing_resource_ids(lines: PackedStringArray) -> Dictionary:
	var lost := {}
	for line in lines:
		if not line.begins_with("[ext_resource"):
			continue
		var path := _quoted_after(line, "path=")
		if path.is_empty() or FileAccess.file_exists(path):
			continue
		lost[_quoted_after(line, "id=")] = path
	return lost


## The file without those ext_resources, without the sub_resources that use
## them, and without the sources entries that point at those sub_resources.
## All three have to go together: leaving a sources line behind pointing at a
## SubResource that no longer exists breaks the file just as thoroughly.
func _without(lines: PackedStringArray, lost_ids: Array) -> PackedStringArray:
	var doomed_subs := {}
	var block_id := ""
	var block_lost := false
	for line in lines:
		if line.begins_with("[sub_resource"):
			block_id = _quoted_after(line, "id=")
			block_lost = false
		elif line.begins_with("["):
			block_id = ""
		elif block_id != "" and line.contains("ExtResource("):
			for id in lost_ids:
				if line.contains('ExtResource("%s")' % id):
					block_lost = true
		if block_lost and block_id != "":
			doomed_subs[block_id] = true

	var out := PackedStringArray()
	var dropping := false
	for line in lines:
		if line.begins_with("["):
			dropping = false
			if line.begins_with("[ext_resource"):
				dropping = lost_ids.has(_quoted_after(line, "id="))
			elif line.begins_with("[sub_resource"):
				dropping = doomed_subs.has(_quoted_after(line, "id="))
		elif line.begins_with("sources/"):
			for sub in doomed_subs:
				if line.contains('SubResource("%s")' % sub):
					dropping = true
			if not dropping:
				out.append(line)
			dropping = false
			continue
		if not dropping:
			out.append(line)
	return out


func _quoted_after(line: String, key: String) -> String:
	var at := line.find(key)
	if at == -1:
		return ""
	var rest := line.substr(at + key.length())
	if not rest.begins_with("\""):
		return ""
	var end := rest.find("\"", 1)
	return rest.substr(1, end - 1) if end > 0 else ""
