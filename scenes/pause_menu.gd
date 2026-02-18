extends CanvasLayer

@onready var pause_menu: CanvasLayer = $"."
@onready var resume_button: Button = $VBoxContainer/ResumeButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	# Hide pause menu initially
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Connect pause menu buttons
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_settings_pressed() -> void:
	print("Settings menu not implemented yet")


func _on_quit_pressed() -> void:
	get_tree().quit()
