## Test: PathConfig
##
## Unit tests for the writeable-path resolver.  In the editor (where
## tests run) all paths must point inside the project at [code]res://[/code].
extends GutTest


func test_use_project_paths_true_in_editor() -> void:
	assert_true(PathConfig.USE_PROJECT_PATHS,
			"USE_PROJECT_PATHS should be true when running under the editor.")


func test_saves_dir_under_res() -> void:
	assert_eq(PathConfig.SAVES_DIR, "res://saves",
			"Editor SAVES_DIR should live inside the project.")


func test_replays_dir_under_res() -> void:
	assert_eq(PathConfig.REPLAYS_DIR, "res://replays",
			"Editor REPLAYS_DIR should live inside the project.")


func test_logs_dir_under_res() -> void:
	assert_eq(PathConfig.LOGS_DIR, "res://logs",
			"Editor LOGS_DIR should live inside the project.")


func test_annotations_dir_under_saves() -> void:
	assert_eq(PathConfig.ANNOTATIONS_DIR,
			PathConfig.SAVES_DIR + "/annotations",
			"ANNOTATIONS_DIR should be a subfolder of SAVES_DIR.")


func test_signing_key_file_under_saves() -> void:
	assert_eq(PathConfig.SIGNING_KEY_FILE,
			PathConfig.SAVES_DIR + "/.signing_key",
			"SIGNING_KEY_FILE should live next to the saves it protects.")


func test_user_data_abs_path_is_absolute() -> void:
	var abs_path: String = PathConfig.user_data_abs_path()
	assert_true(abs_path.is_absolute_path(),
			"user_data_abs_path() should return an absolute path.")
	assert_false(abs_path.begins_with("user://"),
			"user_data_abs_path() should be globalised, not a user:// URI.")
