extends CanvasLayer

@onready var pause_menu: CanvasLayer = $"."
@onready var resume_button: Button = $VBoxContainer/ResumeButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	# Hide pause menu initially
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	if settings_button:
		settings_button.queue_free()
	
	# Connect pause menu buttons
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


func _on_resume_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	pause_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var main = get_parent()
	if main and "is_paused" in main:
		main.is_paused = false


func _on_settings_pressed() -> void:
	pass

func _on_restart_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	var main = get_parent()
	if main and main.has_method("restart_race"):
		main.restart_race()
	else:
		get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()
