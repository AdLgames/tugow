@tool
class_name ModelLibrary
extends RefCounted

## Where the `.modal` files are.
##
## Both screens list the same sounds, so finding them lives here rather than in
## either one. The order of the search is the order of likelihood: beside the
## Godot project when running from the repository, beside the binary when
## exported, and a user directory that survives both.

## Variants the user saves go here when they do not choose somewhere else, so
## a tweaked object is still in the list after a rebuild.
const USER_DIRECTORY := "user://sounds"


static func directories() -> PackedStringArray:
	var project := ProjectSettings.globalize_path("res://")
	return PackedStringArray([
		project.path_join("../models"),
		project.path_join("models"),
		OS.get_executable_path().get_base_dir().path_join("models"),
		ProjectSettings.globalize_path(USER_DIRECTORY),
	])


## Every `.modal` found, de-duplicated by filename so a models/ directory that
## appears twice in the search does not produce twice the presets.
static func discover() -> PackedStringArray:
	var found := PackedStringArray()
	var seen := {}
	for directory in directories():
		# Probing a path that is not there is expected — only some of the
		# candidates exist in any given layout — so it must not be an error.
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for file in DirAccess.get_files_at(directory):
			if not file.ends_with(".modal") or seen.has(file):
				continue
			seen[file] = true
			found.append(directory.path_join(file))
	return found


## The directory a "save as" should open in: wherever the current model came
## from, or the user directory, created on demand.
static func default_save_directory(current_model_path: String) -> String:
	if not current_model_path.is_empty():
		var base := current_model_path.get_base_dir()
		if DirAccess.dir_exists_absolute(base):
			return base
	var user := ProjectSettings.globalize_path(USER_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(user)
	return user
