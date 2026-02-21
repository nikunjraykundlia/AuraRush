extends CanvasLayer

# --- UI Nodes ---
var position_panel: Panel
var position_label: Label
var aura_container: VBoxContainer
var aura_label: Label
var aura_value: Label
var timer_panel: Panel
var timer_label: Label
var best_time_label: Label
var highest_aura_label: Label
var minimap_panel: Panel
var flash_rect: ColorRect
var countdown_panel: Control
var countdown_label: Label
var recover_panel: Panel
var recover_label: Label
var speed_hud_panel: Panel
var speed_label_title: Label
var speed_label_value: Label
var displayed_speed: float = 0.0

# --- State Tracking ---
var current_rank: int = -1
var total_racers: int = 0
var last_rank: int = -1

# --- User Preferences ---
var large_font_mode: bool = false
var high_contrast_mode: bool = false

func _ready():
	_setup_ui()
	
	# Initial state
	if countdown_panel:
		countdown_panel.visible = false
	
	# Connect to parent/main if possible, or wait for main to call methods
	
func _setup_ui():
	# Clean up existing children to ensure fresh layout
	for child in get_children():
		child.queue_free()
		
	# 1. Position Display (Bottom-Right)
	_setup_position_display()
	
	# 2. Aura Display (Right-Center)
	_setup_aura_display()
	
	# 3. Timer & Best Time (Top-Right)
	_setup_timer_display()
	
	# 4. Minimap (Top-Left)
	_setup_minimap_display()
	
	# 5. VFX Overlay
	_get_or_create_flash_rect()
	
	# 6. Countdown (Center)
	_setup_countdown_display()

	# 7. Recover Display (Top-Center)
	_setup_recover_display()
	
	# 8. Speed Display (Right-side, below Aura)
	_setup_speed_display()


func _setup_position_display():
	position_panel = Panel.new()
	position_panel.name = "PositionPanel"
	position_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	# Anchor: x=1%, y=60%
	position_panel.anchor_left = 0.01
	position_panel.anchor_top = 0.6
	position_panel.anchor_right = 0.01
	position_panel.anchor_bottom = 0.6
	# Grow right
	position_panel.grow_horizontal = Control.GROW_DIRECTION_END
	position_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	position_panel.custom_minimum_size = Vector2(160, 80)
	position_panel.position = Vector2(10, 0) # Offset from center-left anchor
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.set_corner_radius_all(8)
	position_panel.add_theme_stylebox_override("panel", style)
	
	add_child(position_panel)
	
	position_label = Label.new()
	position_label.name = "PositionLabel"
	position_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position_label.add_theme_font_size_override("font_size", 40)
	position_label.text = "-/-"
	position_panel.add_child(position_label)

func _setup_aura_display():
	# Add a wrapping Panel to match the SpeedHUD background
	var aura_panel = Panel.new()
	aura_panel.name = "AuraPanel"
	aura_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	# Anchor: x=98%, y=50%
	aura_panel.anchor_left = 0.98
	aura_panel.anchor_top = 0.5
	aura_panel.anchor_right = 0.98
	aura_panel.anchor_bottom = 0.5
	aura_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	aura_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	aura_panel.custom_minimum_size = Vector2(160, 110)
	aura_panel.position = Vector2(-160, -60) # Offset to sit nicely above speedHUD
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.set_corner_radius_all(8)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.5)
	aura_panel.add_theme_stylebox_override("panel", style)
	
	add_child(aura_panel)
	
	aura_container = VBoxContainer.new()
	aura_container.name = "AuraContainer"
	aura_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aura_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	aura_panel.add_child(aura_container)
	
	aura_label = Label.new()
	aura_label.text = "AURA"
	aura_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aura_label.add_theme_font_size_override("font_size", 26)
	aura_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	aura_container.add_child(aura_label)
	
	aura_value = Label.new()
	aura_value.text = "0"
	aura_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aura_value.add_theme_font_size_override("font_size", 32)
	aura_value.modulate = Color(0, 0.96, 1.0) # Cyan
	aura_container.add_child(aura_value)


func _setup_speed_display():
	speed_hud_panel = Panel.new()
	speed_hud_panel.name = "SpeedHUD"
	speed_hud_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	# Anchor: x=98%, y=50%
	speed_hud_panel.anchor_left = 0.98
	speed_hud_panel.anchor_top = 0.5
	speed_hud_panel.anchor_right = 0.98
	speed_hud_panel.anchor_bottom = 0.5
	speed_hud_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	speed_hud_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	speed_hud_panel.custom_minimum_size = Vector2(160, 80)
	
	# Shifted further right, with slightly more space for text
	speed_hud_panel.position = Vector2(-160, 70) 
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.set_corner_radius_all(8)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.5)
	speed_hud_panel.add_theme_stylebox_override("panel", style)
	
	add_child(speed_hud_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_hud_panel.add_child(vbox)
	
	speed_label_title = Label.new()
	speed_label_title.name = "LabelTitle"
	speed_label_title.text = "SPEED"
	speed_label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label_title.add_theme_font_size_override("font_size", 18)
	speed_label_title.add_theme_color_override("font_color", Color("#FFFFFF"))
	vbox.add_child(speed_label_title)
	
	speed_label_value = Label.new()
	speed_label_value.name = "LabelValue"
	speed_label_value.text = "0.0 m/s"
	speed_label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label_value.add_theme_font_size_override("font_size", 20)
	speed_label_value.add_theme_color_override("font_color", Color("#00A2FF"))
	vbox.add_child(speed_label_value)


func _setup_timer_display():
	var timer_panel = Panel.new()
	timer_panel.name = "TimerPanel"
	timer_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# Anchor: x=98%, y=6%
	timer_panel.anchor_left = 0.98
	timer_panel.anchor_top = 0.06
	timer_panel.anchor_right = 0.98
	timer_panel.anchor_bottom = 0.06
	timer_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	
	timer_panel.custom_minimum_size = Vector2(250, 125)
	timer_panel.position = Vector2(-250, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.set_corner_radius_all(8)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.5)
	timer_panel.add_theme_stylebox_override("panel", style)
	
	add_child(timer_panel)
	
	var container = VBoxContainer.new()
	container.name = "TimerContainer"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	timer_panel.add_child(container)
	
	timer_label = Label.new()
	timer_label.text = "00:00.00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 30)
	container.add_child(timer_label)
	
	best_time_label = Label.new()
	best_time_label.text = "BEST TIME --:--.--"
	best_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_time_label.add_theme_font_size_override("font_size", 18)
	best_time_label.modulate = Color(1, 1, 1, 0.7)
	container.add_child(best_time_label)
	
	highest_aura_label = Label.new()
	highest_aura_label.text = "MAX AURA: 0"
	highest_aura_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	highest_aura_label.add_theme_font_size_override("font_size", 18)
	highest_aura_label.modulate = Color(1.0, 0.84, 0.0, 0.85)  # Gold
	container.add_child(highest_aura_label)


var player_map_marker: ColorRect
var bot_map_markers: Array[ColorRect] = []

func _setup_minimap_display():
	minimap_panel = Panel.new()
	minimap_panel.name = "MinimapPanel"
	minimap_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	minimap_panel.anchor_left = 0.02
	minimap_panel.anchor_top = 0.04
	minimap_panel.anchor_right = 0.02
	minimap_panel.anchor_bottom = 0.04
	minimap_panel.grow_horizontal = Control.GROW_DIRECTION_END
	minimap_panel.grow_vertical = Control.GROW_DIRECTION_END
	minimap_panel.custom_minimum_size = Vector2(40, 200) # Tall vertical strip
	minimap_panel.position = Vector2(30, 30) # Manual offset
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(4)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.4)
	minimap_panel.add_theme_stylebox_override("panel", style)
	
	add_child(minimap_panel)
	
	# Track Lane (Visual)
	var track_line = ColorRect.new()
	track_line.color = Color(1, 1, 1, 0.2)
	track_line.custom_minimum_size = Vector2(4, 180)
	track_line.position = Vector2(18, 10) # Center of panel
	minimap_panel.add_child(track_line)
	
	# Start/Finish Lines
	var start_line = ColorRect.new()
	start_line.color = Color(1, 1, 1, 0.5)
	start_line.custom_minimum_size = Vector2(20, 2)
	start_line.position = Vector2(10, 190)
	minimap_panel.add_child(start_line)
	
	var finish_line = ColorRect.new()
	finish_line.color = Color(1, 1, 1, 0.5)
	finish_line.custom_minimum_size = Vector2(20, 2)
	finish_line.position = Vector2(10, 10)
	minimap_panel.add_child(finish_line)

func init_minimap_markers(bot_colors: Array):
	# Player Marker
	player_map_marker = ColorRect.new()
	player_map_marker.color = Color(1.0, 1.0, 1.0) # White
	player_map_marker.custom_minimum_size = Vector2(12, 12)
	# Center pivot for easier positioning
	player_map_marker.pivot_offset = Vector2(6, 6)
	minimap_panel.add_child(player_map_marker)
	
	# Bot Markers
	for color in bot_colors:
		var marker = ColorRect.new()
		marker.color = color
		marker.custom_minimum_size = Vector2(10, 10)
		marker.pivot_offset = Vector2(5, 5)
		minimap_panel.add_child(marker)
		bot_map_markers.append(marker)

func update_minimap(player_prog: float, bot_progs: Array):
	# Map height is 200, but use usable area 10 to 190 (180 height)
	var map_height = 180.0
	var start_y = 190.0
	
	# Player
	# Clamp progress 0 to 1
	var p_prog = clampf(player_prog, 0.0, 1.0)
	var p_y = start_y - (p_prog * map_height)
	player_map_marker.position = Vector2(14, p_y - 6) # x centered (40 width -> 20 center - 6 half size = 14)
	
	# Bots
	for i in range(len(bot_map_markers)):
		if i < len(bot_progs):
			var b_prog = clampf(bot_progs[i], 0.0, 1.0)
			var b_y = start_y - (b_prog * map_height)
			# Offset bots slightly based on index to avoid total overlap if speeds are same
			var x_offset = (i % 2) * 6 - 3 
			bot_map_markers[i].position = Vector2(15 + x_offset, b_y - 5)

func _get_or_create_flash_rect():
	flash_rect = ColorRect.new()
	flash_rect.name = "FlashRect"
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(0, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

func _setup_countdown_display():
	countdown_panel = Control.new()
	countdown_panel.name = "CountdownPanel"
	countdown_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_panel.visible = false
	add_child(countdown_panel)
	
	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 160)
	countdown_label.add_theme_constant_override("outline_size", 8)
	countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	countdown_panel.add_child(countdown_label)

func _setup_recover_display():
	recover_panel = Panel.new()
	recover_panel.name = "RecoverPanel"
	recover_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# Center top, small size
	recover_panel.anchor_left = 0.4
	recover_panel.anchor_right = 0.6
	recover_panel.anchor_top = 0.05
	recover_panel.anchor_bottom = 0.12
	recover_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	recover_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	recover_panel.visible = false
	
	# Transparent bg or stylized
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(6)
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.2, 0.2) # Reddish warning
	recover_panel.add_theme_stylebox_override("panel", style)
	
	add_child(recover_panel)
	
	recover_label = Label.new()
	recover_label.name = "RecoverLabel"
	recover_label.text = "RECOVER"
	recover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recover_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recover_label.add_theme_font_size_override("font_size", 28)
	recover_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	recover_panel.add_child(recover_label)

# --- Updates ---

func update_rank(rank: int, total: int):
	# Update text
	position_label.text = "%d/%d" % [rank, total]
	
	# Logic for flash
	if last_rank != -1 and rank != last_rank:
		if rank < last_rank:
			# Gained position (e.g. 2nd -> 1st)
			_trigger_flash(Color("#00FF6A"), 0.3)
		elif rank > last_rank:
			# Lost position (e.g. 1st -> 2nd)
			_trigger_flash(Color("#FF4D4D"), 0.3)
			
	last_rank = rank
	total_racers = total

func update_aura(current_points: float):
	aura_value.text = str(int(current_points))

func update_speed_display(measured_speed: float, delta: float):
	if !speed_hud_panel.visible:
		return
	displayed_speed = lerpf(displayed_speed, measured_speed, clampf(delta * 10.0, 0.0, 1.0))
	speed_label_value.text = "%.1f m/s" % displayed_speed

func toggle_speed_hud():
	if speed_hud_panel:
		speed_hud_panel.visible = !speed_hud_panel.visible


func pulse_aura_display():
	var tween = create_tween()
	aura_value.scale = Vector2(1.5, 1.5)
	tween.tween_property(aura_value, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)

func update_timer_display(time_sec: float):
	timer_label.text = _format_time(time_sec)

func update_best_time_display(time_sec: float):
	if time_sec <= 0:
		best_time_label.text = "Best Time --:--.--"
	else:
		best_time_label.text = "Best Time " + _format_time(time_sec)

func update_highest_aura_display(aura_val: float):
	if aura_val <= 0:
		highest_aura_label.text = "Max Aura: --"
	else:
		highest_aura_label.text = "Max Aura: %d" % int(aura_val)

func _format_time(time_sec: float) -> String:
	var m = int(time_sec / 60)
	var s = int(time_sec) % 60
	var ms = int((time_sec - int(time_sec)) * 100)
	return "%02d:%02d.%02d" % [m, s, ms]

func show_countdown_step(step: Variant):
	if !countdown_panel: return
	
	countdown_panel.visible = true
	var step_str = str(step)
	countdown_label.text = step_str
	
	var color: Color
	match step_str:
		"3":
			color = Color(1.0, 0.15, 0.3) * 2.5 # Neon Red/Pink
		"2":
			color = Color(1.0, 0.84, 0.0) * 2.5 # Neon Gold/Yellow
		"1":
			color = Color(0.0, 0.96, 1.0) * 2.5 # Neon Cyan
		"GO":
			color = Color(0.0, 1.0, 0.41) * 3.0 # Strong Neon Green
		_:
			color = Color(1.0, 1.0, 1.0) * 2.0
			
	var is_go = step_str == "GO"
	countdown_label.modulate = color
	
	# Professional Pulse animation
	var tween = create_tween()
	countdown_label.scale = Vector2(0.3, 0.3)
	countdown_label.rotation_degrees = -15.0 if not is_go else 0.0
	
	tween.set_parallel(true)
	tween.tween_property(countdown_label, "scale", Vector2(1.2, 1.2), 0.5)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)
	
	if not is_go:
		tween.tween_property(countdown_label, "rotation_degrees", 0.0, 0.4)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(countdown_label, "scale", Vector2(1.5, 1.5), 0.3)\
			.set_trans(Tween.TRANS_ELASTIC)\
			.set_ease(Tween.EASE_OUT)
		
		tween.chain().tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.5)\
			.set_trans(Tween.TRANS_SINE)

func hide_countdown():
	if countdown_panel:
		countdown_panel.visible = false

func show_recover_alert():
	if recover_panel:
		recover_panel.visible = true
		
		# Simple pulse
		var tween = create_tween()
		recover_label.scale = Vector2(0.9, 0.9)
		tween.tween_property(recover_label, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(recover_label, "scale", Vector2(1.0, 1.0), 0.2)

func hide_recover_alert():
	if recover_panel:
		recover_panel.visible = false

func show_race_complete(winner_name: String, final_pos: int, total: int):
	# 1. Full screen dimmer
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	add_child(overlay)
	
	# 2. Centered Results Box
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center_container)
	
	var panel_container = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.0, 0.96, 1.0) # Cyan border
	style.set_corner_radius_all(10)
	style.expand_margin_left = 20
	style.expand_margin_right = 20
	style.expand_margin_top = 20
	style.expand_margin_bottom = 20
	panel_container.add_theme_stylebox_override("panel", style)
	center_container.add_child(panel_container)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel_container.add_child(vbox)
	
	# Title
	var label = Label.new()
	label.text = "RACE FINISHED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(label)
	
	# Winner
	var sublabel = Label.new()
	if winner_name == "Player":
		sublabel.text = "YOU WON!"
		sublabel.add_theme_color_override("font_color", Color.GREEN)
	else:
		sublabel.text = "Winner: %s" % winner_name
		sublabel.add_theme_color_override("font_color", Color(1, 0.2, 0.2)) # Reddish
	
	sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sublabel.add_theme_font_size_override("font_size", 48)
	vbox.add_child(sublabel)
	
	# Rank
	var poslabel = Label.new()
	poslabel.text = "Position: %d / %d" % [final_pos, total]
	poslabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poslabel.add_theme_font_size_override("font_size", 36)
	vbox.add_child(poslabel)
	
	# Best Time note
	var time_label = Label.new()
	time_label.text = "Check Best Time and Max Aura\nPress R to Restart"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(time_label)
	
	# Animate in
	panel_container.scale = Vector2(0, 0)
	panel_container.pivot_offset = Vector2(200, 150) # Approx center
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_aura_bonus(amount: int):
	# Create a floating label for bonus
	var label = Label.new()
	label.text = "+%d" % amount
	label.modulate = Color(0, 1, 0) # Green
	label.add_theme_font_size_override("font_size", 32)
	
	# Add directly to hud so it's on top, position near aura container
	add_child(label)
	# Default position near aura container (right-center)
	# Aura container is at x=92%, y=50%
	# We'll set a safe position
	label.position = Vector2(get_viewport().size.x * 0.9, get_viewport().size.y * 0.45)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 80, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)

func _trigger_flash(color: Color, duration: float):
	var flash = flash_rect.duplicate()
	add_child(flash)
	flash.color = color
	flash.color.a = 0.3
	
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)
