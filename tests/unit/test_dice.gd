## Test: Dice
##
## Unit tests for the Dice class — rolling, damage calculation, and face properties.
extends GutTest


# --- Roll Die ---

func test_roll_die_red_returns_valid_face() -> void:
	for i in range(100):
		var face := Dice.roll_die(Constants.DiceColor.RED)
		assert_true(
			face in Dice.DICE_FACES[Constants.DiceColor.RED],
			"Red die should return a valid red face"
		)


func test_roll_die_blue_returns_valid_face() -> void:
	for i in range(100):
		var face := Dice.roll_die(Constants.DiceColor.BLUE)
		assert_true(
			face in Dice.DICE_FACES[Constants.DiceColor.BLUE],
			"Blue die should return a valid blue face"
		)


func test_roll_die_black_returns_valid_face() -> void:
	for i in range(100):
		var face := Dice.roll_die(Constants.DiceColor.BLACK)
		assert_true(
			face in Dice.DICE_FACES[Constants.DiceColor.BLACK],
			"Black die should return a valid black face"
		)


# --- Dice Face Properties ---

func test_red_die_has_eight_faces() -> void:
	assert_eq(Dice.DICE_FACES[Constants.DiceColor.RED].size(), 8, "Red die should have 8 faces")


func test_blue_die_has_eight_faces() -> void:
	assert_eq(Dice.DICE_FACES[Constants.DiceColor.BLUE].size(), 8, "Blue die should have 8 faces")


func test_black_die_has_eight_faces() -> void:
	assert_eq(Dice.DICE_FACES[Constants.DiceColor.BLACK].size(), 8, "Black die should have 8 faces")


func test_blue_die_has_no_blanks() -> void:
	var faces: Array = Dice.DICE_FACES[Constants.DiceColor.BLUE]
	assert_false(Constants.DiceFace.BLANK in faces, "Blue die should have no blank faces")


# --- Damage Calculation ---

func test_get_face_damage_hit() -> void:
	assert_eq(Dice.get_face_damage(Constants.DiceFace.HIT), 1, "HIT should deal 1 damage")


func test_get_face_damage_critical() -> void:
	assert_eq(Dice.get_face_damage(Constants.DiceFace.CRITICAL), 1, "CRITICAL should deal 1 damage")


func test_get_face_damage_hit_critical() -> void:
	assert_eq(Dice.get_face_damage(Constants.DiceFace.HIT_CRITICAL), 2, "HIT_CRITICAL should deal 2 damage")


func test_get_face_damage_hit_hit() -> void:
	assert_eq(Dice.get_face_damage(Constants.DiceFace.HIT_HIT), 2, "HIT_HIT should deal 2 damage")


func test_get_face_damage_accuracy() -> void:
	assert_eq(Dice.get_face_damage(Constants.DiceFace.ACCURACY), 0, "ACCURACY should deal 0 damage")


func test_get_face_damage_blank() -> void:
	assert_eq(Dice.get_face_damage(Constants.DiceFace.BLANK), 0, "BLANK should deal 0 damage")


# --- Critical Detection ---

func test_has_critical_for_critical_face() -> void:
	assert_true(Dice.has_critical(Constants.DiceFace.CRITICAL), "CRITICAL face has critical")


func test_has_critical_for_hit_critical_face() -> void:
	assert_true(Dice.has_critical(Constants.DiceFace.HIT_CRITICAL), "HIT_CRITICAL face has critical")


func test_has_critical_for_hit_face() -> void:
	assert_false(Dice.has_critical(Constants.DiceFace.HIT), "HIT face does not have critical")


func test_has_critical_for_blank_face() -> void:
	assert_false(Dice.has_critical(Constants.DiceFace.BLANK), "BLANK face does not have critical")


# --- Accuracy Detection ---

func test_is_accuracy_for_accuracy_face() -> void:
	assert_true(Dice.is_accuracy(Constants.DiceFace.ACCURACY), "ACCURACY face is accuracy")


func test_is_accuracy_for_hit_face() -> void:
	assert_false(Dice.is_accuracy(Constants.DiceFace.HIT), "HIT face is not accuracy")


# --- Roll Pool ---

func test_roll_pool_returns_correct_count() -> void:
	var pool := {Constants.DiceColor.RED: 2, Constants.DiceColor.BLUE: 1}
	var results := Dice.roll_pool(pool)
	assert_eq(results.size(), 3, "Pool of 2 red + 1 blue should return 3 results")


func test_roll_pool_empty_returns_empty() -> void:
	var pool := {}
	var results := Dice.roll_pool(pool)
	assert_eq(results.size(), 0, "Empty pool should return 0 results")


func test_roll_pool_results_have_color_and_face() -> void:
	var pool := {Constants.DiceColor.BLACK: 1}
	var results := Dice.roll_pool(pool)
	assert_eq(results.size(), 1)
	assert_has(results[0], "color", "Result should have 'color' key")
	assert_has(results[0], "face", "Result should have 'face' key")


# --- Calculate Damage ---

func test_calculate_damage_all_hits() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
	]
	assert_eq(Dice.calculate_damage(results), 2, "Two HITs should deal 2 damage")


func test_calculate_damage_mixed() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT_HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.ACCURACY},
		{"color": Constants.DiceColor.BLACK, "face": Constants.DiceFace.BLANK},
	]
	assert_eq(Dice.calculate_damage(results), 2, "HIT_HIT + ACCURACY + BLANK = 2 damage")


func test_calculate_damage_empty() -> void:
	var results: Array[Dictionary] = []
	assert_eq(Dice.calculate_damage(results), 0, "Empty results should deal 0 damage")


# --- Calculate Damage vs Squadron ---

func test_calculate_damage_vs_squadron_hit_counts() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
	]
	assert_eq(Dice.calculate_damage_vs_squadron(results), 2,
			"HITs should deal normal damage vs squadrons")


func test_calculate_damage_vs_squadron_crit_ignored() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL},
	]
	assert_eq(Dice.calculate_damage_vs_squadron(results), 0,
			"CRITICAL should deal 0 damage vs squadrons (RRG Dice Icons p.5)")


func test_calculate_damage_vs_squadron_hit_crit_counts_hit_only() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.BLACK, "face": Constants.DiceFace.HIT_CRITICAL},
	]
	assert_eq(Dice.calculate_damage_vs_squadron(results), 1,
			"HIT_CRITICAL should deal 1 (hit only) vs squadrons")


func test_calculate_damage_vs_squadron_hit_hit_counts_both() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT_HIT},
	]
	assert_eq(Dice.calculate_damage_vs_squadron(results), 2,
			"HIT_HIT should deal 2 damage vs squadrons")


func test_calculate_damage_vs_squadron_mixed_pool() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL},
		{"color": Constants.DiceColor.BLACK, "face": Constants.DiceFace.HIT_CRITICAL},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.ACCURACY},
	]
	assert_eq(Dice.calculate_damage_vs_squadron(results), 2,
			"HIT(1) + CRIT(0) + HIT_CRIT(1) + ACC(0) = 2 vs squadrons")


func test_calculate_damage_vs_squadron_empty() -> void:
	var results: Array[Dictionary] = []
	assert_eq(Dice.calculate_damage_vs_squadron(results), 0,
			"Empty results should deal 0 damage vs squadrons")


# --- get_face_image_path ---

func test_get_face_image_path_red_hit_returns_correct_path() -> void:
	# Arrange / Act
	var path: String = Dice.get_face_image_path(
			Constants.DiceColor.RED, Constants.DiceFace.HIT)
	# Assert
	assert_eq(path,
			"res://Resources/Game_Components/dice/die_red_hit.png",
			"Red HIT should map to die_red_hit.png")


func test_get_face_image_path_blue_accuracy_returns_correct_path() -> void:
	var path: String = Dice.get_face_image_path(
			Constants.DiceColor.BLUE, Constants.DiceFace.ACCURACY)
	assert_eq(path,
			"res://Resources/Game_Components/dice/die_blue_accuracy.png",
			"Blue ACCURACY path")


func test_get_face_image_path_black_hit_crit_returns_correct_path() -> void:
	var path: String = Dice.get_face_image_path(
			Constants.DiceColor.BLACK, Constants.DiceFace.HIT_CRITICAL)
	assert_eq(path,
			"res://Resources/Game_Components/dice/die_black_hit_crit.png",
			"Black HIT_CRITICAL path")


func test_get_face_image_path_red_blank_returns_correct_path() -> void:
	var path: String = Dice.get_face_image_path(
			Constants.DiceColor.RED, Constants.DiceFace.BLANK)
	assert_eq(path,
			"res://Resources/Game_Components/dice/die_red_blank.png",
			"Red BLANK path")


func test_get_face_image_path_red_hit_hit_returns_correct_path() -> void:
	var path: String = Dice.get_face_image_path(
			Constants.DiceColor.RED, Constants.DiceFace.HIT_HIT)
	assert_eq(path,
			"res://Resources/Game_Components/dice/die_red_hit_hit.png",
			"Red HIT_HIT path")


func test_get_face_image_path_black_crit_returns_correct_path() -> void:
	var path: String = Dice.get_face_image_path(
			Constants.DiceColor.BLACK, Constants.DiceFace.CRITICAL)
	assert_eq(path,
			"res://Resources/Game_Components/dice/die_black_crit.png",
			"Black CRITICAL path")


func test_get_face_image_path_all_colours_all_faces_have_valid_paths() -> void:
	# Every colour × face combo should produce a non-empty path.
	var colours: Array = [
		Constants.DiceColor.RED,
		Constants.DiceColor.BLUE,
		Constants.DiceColor.BLACK,
	]
	var faces: Array = [
		Constants.DiceFace.BLANK,
		Constants.DiceFace.HIT,
		Constants.DiceFace.CRITICAL,
		Constants.DiceFace.HIT_CRITICAL,
		Constants.DiceFace.ACCURACY,
		Constants.DiceFace.HIT_HIT,
	]
	for color in colours:
		for face in faces:
			var path: String = Dice.get_face_image_path(color, face)
			assert_true(path.begins_with("res://"),
					"Path for %d/%d should start with res://" % [
					color, face])
			assert_true(path.ends_with(".png"),
					"Path for %d/%d should end with .png" % [
					color, face])
