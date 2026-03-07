## Main Menu
##
## Entry point scene for the game. Provides navigation to game modes.
extends Control


func _ready() -> void:
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)


func _on_new_game_pressed() -> void:
	# TODO: Transition to fleet builder or game setup scene
	pass


func _on_quit_pressed() -> void:
	get_tree().quit()
