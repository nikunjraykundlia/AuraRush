extends Node3D

# ============================================================================
# AURA RUSH - Straight Track Racing with Aura Collection System
# ============================================================================

# --- Race Configuration ---
const NUM_BOTS := 3
const TRACK_LENGTH := 2000.0          # Total track distance in meters
const TRACK_WIDTH := 16.0             # Lane width
const NUM_LANES := 4                  # Number of driving lanes
const LANE_WIDTH := TRACK_WIDTH / NUM_LANES

# --- Aura System Configuration ---
const AURA_MAX := 100.0
const AURA_BURST_DURATION := 3.0
const AURA_BURST_SPEED_MULT := 1.45
const AURA_ORB_VALUE := 5.0
const AURA_DRIFT_RATE := 2.0          # Aura per second while drifting
const AURA_OVERTAKE_BONUS := 10.0
const AURA_PROXIMITY_RATE := 1.0      # Aura per second near opponents
const AURA_COLLISION_PENALTY := 15.0
const AURA_OFFTRACK_DRAIN := 3.0      # Aura drain per second off-track

# --- Player Physics ---
const PLAYER_MAX_SPEED := 55.0
const PLAYER_ACCEL := 35.0
const PLAYER_STEER_SPEED := 8.0
const PLAYER_BRAKE_FORCE := 50.0

# --- Bot AI Configuration ---
var BOT_BASE_SPEEDS: Array[float] = [40.0, 42.0, 45.0]
const BOT_LANE_CHANGE_COOLDOWN := 1.5
const BOT_REACTION_TIME := 0.22

# --- Camera Configuration ---
const CAM_HEIGHT := 18.0
const CAM_DISTANCE := 12.0
const CAM_LOOKAHEAD := 15.0
const CAM_SMOOTH_SPEED := 6.0

# --- Telemetry Signals ---
signal countdown_started
signal countdown_step(step)
signal countdown_completed
signal race_started
signal race_finished(winner)

# --- Track Segments ---
var track_segments: Array[MeshInstance3D] = []
var aura_orbs: Array[Node3D] = []

# --- Player State ---
var player_body: VehicleBody3D 
var player_mesh: MeshInstance3D
var player_position: float = 0.0       # Distance along track
var player_lane: int = 1               # Current lane (0-3) - approximate
var player_x_offset: float = 0.0

# --- Aura State ---
var aura_meter: float = 0.0
var aura_burst_active: bool = false
var aura_burst_timer: float = 0.0
var aura_streak_multiplier: float = 1.0
var is_drifting: bool = false

# --- Bot State ---
var bot_bodies: Array[RigidBody3D] = []
var bot_meshes: Array[MeshInstance3D] = []
var bot_positions: Array[float] = []   # Distance along track
var bot_lanes: Array[int] = []
var bot_speeds: Array[float] = []
var bot_lane_change_timers: Array[float] = []
var ai_active: bool = false

# --- Race State ---
var race_state: String = "init"   # init, countdown, racing, finished
var countdown_value: int = 3
var countdown_timer: float = 0.0
var race_time: float = 0.0
var distance_traveled: float = 0.0
var player_rank: int = 1
var last_player_rank: int = 1 # To detect changes
var winner: String = ""

# --- Persistence ---
var best_time_2000m: float = 0.0
const SAVE_PATH = "user://save_data.cfg"

# --- UI Elements ---
var hud: CanvasLayer

# --- References ---
var player_cam: Camera3D
var is_paused: bool = false
@onready var pause_menu = $PauseMenu

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Find references
	player_body = $Car
	player_body.rotation_degrees.y = 180.0
	hud = $HUD

	_load_data()
	
	_setup_track()
	# Bots setup
	_setup_bots()
	_setup_aura_orbs()
	
	# Initial Lock
	if player_body.has_method("set_input_enabled"):
		player_body.set_input_enabled(false)
	
	# Init HUD
	if hud:
		hud.update_best_time_display(best_time_2000m)
		hud.update_aura(aura_meter)
		hud.update_rank(1, NUM_BOTS + 1)
	
	# Allow a momentary delay before countdown starts so scene loads fully
	await get_tree().create_timer(1.0).timeout
	_start_countdown()

func _setup_track() -> void:
	# Create straight track segments with lane markings
	var segment_length := 100.0
	var num_segments := int(TRACK_LENGTH / segment_length) + 6 # Extra segments for overrun
	
	for i in range(num_segments):
		# Main road surface
		var body := StaticBody3D.new()
		body.position = Vector3(0.0, -10.0, float(i) * segment_length)
		add_child(body)
		
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(TRACK_WIDTH, 20.0, segment_length)
		col.shape = shape
		body.add_child(col)
		
		var seg := MeshInstance3D.new()
		seg.mesh = BoxMesh.new()
		seg.mesh.size = Vector3(TRACK_WIDTH, 20.0, segment_length)
		seg.mesh.material = _create_track_material()
		body.add_child(seg)
		
		track_segments.append(seg)
		
		# Lane dividers
		for lane in range(1, NUM_LANES):
			var divider := MeshInstance3D.new()
			divider.mesh = BoxMesh.new()
			divider.mesh.size = Vector3(0.15, 0.6, segment_length * 0.4)
			var lane_x := -TRACK_WIDTH / 2.0 + lane * LANE_WIDTH
			divider.position = Vector3(lane_x, 0.3, float(i) * segment_length)
			divider.mesh.material = _create_neon_material(Color(1.0, 1.0, 1.0, 0.6))
			add_child(divider)
		
		# Track edge barriers (neon)
		for side in [-1, 1]:
			var barrier_body := StaticBody3D.new()
			# Add frictionless material to prevent sticking
			var friction_mat := PhysicsMaterial.new()
			friction_mat.friction = 0.0
			friction_mat.bounce = 0.5
			barrier_body.physics_material_override = friction_mat
			
			barrier_body.position = Vector3(side * (TRACK_WIDTH / 2.0 + 0.25), 0.75, float(i) * segment_length)
			add_child(barrier_body)
			
			var barrier_col := CollisionShape3D.new()
			var barrier_shape := BoxShape3D.new()
			barrier_shape.size = Vector3(0.5, 1.5, segment_length)
			barrier_col.shape = barrier_shape
			barrier_body.add_child(barrier_col)
			
			var barrier_mesh := MeshInstance3D.new()
			barrier_mesh.mesh = BoxMesh.new()
			barrier_mesh.mesh.size = Vector3(0.5, 1.5, segment_length)
			var barrier_color := Color(0.0, 0.96, 1.0) if side == -1 else Color(1.0, 0.15, 0.49)
			barrier_mesh.mesh.material = _create_neon_material(barrier_color)
			barrier_body.add_child(barrier_mesh)

	# End Wall at the very end of the track
	var end_z = num_segments * segment_length
	var e_body = StaticBody3D.new()
	e_body.position = Vector3(0, 10, end_z)
	add_child(e_body)
	
	var ec = CollisionShape3D.new()
	ec.shape = BoxShape3D.new()
	ec.shape.size = Vector3(TRACK_WIDTH * 3, 40, 5)
	e_body.add_child(ec)
	
	var em = MeshInstance3D.new()
	em.mesh = BoxMesh.new()
	em.mesh.size = Vector3(TRACK_WIDTH * 3, 40, 5)
	em.mesh.material = _create_neon_material(Color(1, 0, 0)) # Red
	e_body.add_child(em)

func _setup_bots() -> void:
	var bot_colors: Array[Color] = [
		Color(1.0, 0.15, 0.49),  # Pink
		Color(1.0, 0.85, 0.0),   # Yellow
		Color(0.0, 1.0, 0.4)     # Green
	]
	
	for i in range(NUM_BOTS):
		var bot := RigidBody3D.new()
		bot.mass = 1200.0
		bot.name = "Bot%d" % i
		bot.gravity_scale = 0.0
		bot.lock_rotation = true
		
		# Staggered start positions
		var bot_lane := (i + 2) % NUM_LANES
		var bot_x := _lane_to_x(bot_lane)
		var bot_z := 5.0 - float(i + 1) * 3.0  # Staggered behind player relative to 0
		bot.position = Vector3(bot_x, 1.5, bot_z)
		bot.rotation_degrees.y = 180.0
		add_child(bot)
		bot_bodies.append(bot)
		
		var bot_mesh := MeshInstance3D.new()
		bot_mesh.mesh = BoxMesh.new()
		bot_mesh.mesh.size = Vector3(2.0, 1.0, 4.0)
		bot_mesh.mesh.material = _create_neon_material(bot_colors[i])
		bot.add_child(bot_mesh)
		bot_meshes.append(bot_mesh)
		
		# Bot collision
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 1.0, 4.0)
		collision.shape = shape
		bot.add_child(collision)
		
		# Initialize bot state
		bot_positions.append(bot_z)
		bot_lanes.append(bot_lane)
		# Randomize bot speed for this session
		var speed = randf_range(40.0, 52.0) # Speed varying between 40 and 52 km/h (converted to units) 
		# Note: The speeds in main.gd seem to be in units per second, not km/h directly, but 40-45 was previous range.
		# Let's make it wider and purely random.
		bot_speeds.append(speed)
		bot_lane_change_timers.append(0.0)
	
	if hud:
		hud.init_minimap_markers(bot_colors)

func _setup_aura_orbs() -> void:
	# Spawn aura orbs along the track
	var orb_spacing := 40.0
	var num_orbs := int(TRACK_LENGTH / orb_spacing)
	
	for i in range(num_orbs):
		var orb := MeshInstance3D.new()
		orb.mesh = SphereMesh.new()
		orb.mesh.radius = 0.8
		orb.mesh.height = 1.6
		orb.mesh.material = _create_aura_orb_material()
		
		# Random lane placement with some risk-reward positioning
		var orb_lane := randi() % NUM_LANES
		var orb_x := _lane_to_x(orb_lane)
		var orb_z := float(i + 1) * orb_spacing + randf_range(-5.0, 5.0)
		orb.position = Vector3(orb_x, 2.0, orb_z)
		orb.name = "AuraOrb_%d" % i
		
		add_child(orb)
		aura_orbs.append(orb)

# ============================================================================
# MATERIALS
# ============================================================================

func _create_track_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.18)
	mat.roughness = 0.8
	return mat

func _create_neon_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	return mat

func _create_aura_orb_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.96, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.96, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

# ============================================================================
# COUNTDOWN SYSTEM
# ============================================================================

func _start_countdown() -> void:
	race_state = "countdown"
	countdown_value = 3
	countdown_timer = 0.0
	emit_signal("countdown_started")
	if hud:
		hud.show_countdown_step(3)
	emit_signal("countdown_step", 3)

func _update_countdown(delta: float) -> void:
	countdown_timer += delta
	
	if countdown_timer >= 1.0:
		countdown_timer = 0.0
		countdown_value -= 1
		
		if countdown_value > 0:
			if hud: hud.show_countdown_step(countdown_value)
			emit_signal("countdown_step", countdown_value)
		elif countdown_value == 0:
			if hud: hud.show_countdown_step("GO")
			_unlock_race_start()
		else:
			if hud: hud.hide_countdown()
			race_state = "racing"

func _unlock_race_start() -> void:
	emit_signal("countdown_completed")
	emit_signal("race_started")
	
	# Player unlock
	if player_body.has_method("set_input_enabled"):
		player_body.set_input_enabled(true, true) # Enabled=true, FlushBuffered=true
	
	# AI unlock
	ai_active = true
	_apply_ai_launch_impulses()
	
	# Allow a slight moment before hiding "GO" is handled by the countdown update loop

func _apply_ai_launch_impulses() -> void:
	for i in range(NUM_BOTS):
		# Variation: 5% variation as requested
		var variation_pct = 0.05
		var variation = randf_range(1.0 - variation_pct, 1.0 + variation_pct)
		# Just modifying their initial speed boost effectively
		bot_speeds[i] *= variation

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	
	if event.is_action_pressed("ui_cancel") and not is_paused:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_pause() -> void:
	is_paused = !is_paused
	if pause_menu:
		pause_menu.visible = is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ============================================================================
# GAME LOOP
# ============================================================================

func _process(delta: float) -> void:
	if is_paused:
		return
	
	match race_state:
		"countdown":
			_update_countdown(delta)
		"racing":
			_update_aura_system(delta)
			_check_aura_orb_collection()
			_update_race_progress(delta)
			
			if hud:
				hud.update_timer_display(race_time)
				
		"finished":
			pass

func _physics_process(delta: float) -> void:
	if is_paused:
		return
		
	if race_state == "racing":
		_update_bot_ai(delta)
		_check_collisions()
		_update_rankings()
		
		# Update player position tracking for game logic
		if player_body:
			player_position = player_body.global_position.z
			player_x_offset = player_body.global_position.x
			player_lane = _x_to_lane(player_x_offset)
			
			# UI Update Rate limiter could be implemented here if needed, but per-frame is smooth
			if hud:
				hud.update_rank(player_rank, NUM_BOTS + 1)
				hud.update_aura(aura_meter)
				
				# Minimap update
				var player_prog = player_position / TRACK_LENGTH
				var bot_progs = []
				for pos in bot_positions:
					bot_progs.append(pos / TRACK_LENGTH)
				hud.update_minimap(player_prog, bot_progs)
		
		_check_player_fall_respawn()

func _check_player_fall_respawn() -> void:
	if not player_body: return
	
	# If player falls below -10.0 (track is around -10 or 0 usually, safe buffer)
	if player_body.global_position.y < -15.0:
		_respawn_player()

func _respawn_player() -> void:
	if not player_body: return
	
	# Current track distance
	var current_z = player_body.global_position.z
	
	# Respawn slightly back or at same Z, centered on track, slightly above
	var safe_z = current_z
	var safe_x = 0.0 # Center lane
	
	# Reset physics
	player_body.linear_velocity = Vector3.ZERO
	player_body.angular_velocity = Vector3.ZERO
	player_body.global_position = Vector3(safe_x, 2.0, safe_z)
	player_body.global_rotation = Vector3.ZERO
	
	# Ensure looking forward (forward is -Z in Godot usually, but track goes +Z?
	# Let's check rotation in setup: player_body.rotation_degrees.y = 180.0
	# So car faces +Z if model is -Z forward.
	# The setup says: player_body.rotation_degrees.y = 180.0
	# And track generates +Z segments.
	player_body.rotation_degrees = Vector3(0, 180, 0)
	
	# Penalty? maybe flash screen or lose speed (implied by velocity reset)
	if hud:
		hud.show_countdown_step("!") # Quick visual indicator
		# Optionally hide it after a moment or let usage clear it
		get_tree().create_timer(1.0).timeout.connect(func(): hud.hide_countdown())

# ============================================================================
# AURA SYSTEM
# ============================================================================

func _update_aura_system(delta: float) -> void:
	# Aura burst timer
	if aura_burst_active:
		aura_burst_timer -= delta
		if aura_burst_timer <= 0.0:
			aura_burst_active = false
	
	# Drift aura gain - need to get drift state from car controller
	pass

func _check_aura_orb_collection() -> void:
	var pickup_radius := 2.5
	
	for orb in aura_orbs:
		if orb == null or not orb.visible:
			continue
		
		var dist := player_body.position.distance_to(orb.position)
		if dist < pickup_radius:
			_collect_aura_orb(orb)

func _collect_aura_orb(orb: Node3D) -> void:
	_add_aura(AURA_ORB_VALUE * aura_streak_multiplier)
	orb.visible = false
	if hud:
		hud.pulse_aura_display()

func _add_aura(amount: float) -> void:
	aura_meter = minf(aura_meter + amount, AURA_MAX)

# ============================================================================
# BOT AI
# ============================================================================

func _update_bot_ai(delta: float) -> void:
	if not ai_active:
		return

	for i in range(NUM_BOTS):
		var bot := bot_bodies[i]
		
		# Update lane change cooldown
		bot_lane_change_timers[i] = maxf(bot_lane_change_timers[i] - delta, 0.0)
		
		# Move forward
		bot_positions[i] += bot_speeds[i] * delta
		
		# Simple lane change AI
		if bot_lane_change_timers[i] <= 0.0:
			_bot_consider_lane_change(i)
		
		# Update bot position
		var bot_x := _lane_to_x(bot_lanes[i])
		var current_z = bot_positions[i]
		bot.position = Vector3(bot_x, 1.5, current_z)

func _bot_consider_lane_change(bot_index: int) -> void:
	# Check if player is ahead in same lane - try to block or overtake
	var bot_lane := bot_lanes[bot_index]
	
	# Random lane change for variety
	if randf() < 0.02:  # 2% chance per frame when cooldown is 0
		var new_lane := bot_lane + (randi() % 3 - 1)  # -1, 0, or +1
		new_lane = clampi(new_lane, 0, NUM_LANES - 1)
		if new_lane != bot_lane:
			bot_lanes[bot_index] = new_lane
			bot_lane_change_timers[bot_index] = BOT_LANE_CHANGE_COOLDOWN

# ============================================================================
# COLLISION & RANKING
# ============================================================================

func _check_collisions() -> void:
	var collision_radius := 2.5
	
	for i in range(NUM_BOTS):
		var bot := bot_bodies[i]
		var dist := player_body.position.distance_to(bot.position)
		
		if dist < collision_radius:
			# Collision penalty
			aura_meter = maxf(aura_meter - AURA_COLLISION_PENALTY, 0.0)
			aura_streak_multiplier = 1.0

func _update_rankings() -> void:
	# Calculate player rank based on position
	var rank := 1
	for i in range(NUM_BOTS):
		if bot_positions[i] > player_position:
			rank += 1
			
	# Check for overtake (rank improved, e.g., went from 2 to 1)
	if last_player_rank != 0 and rank < last_player_rank:
		# Player overtook someone
		_on_overtake()
		
	player_rank = rank
	last_player_rank = rank

func _on_overtake() -> void:
	_add_aura(AURA_OVERTAKE_BONUS)
	if hud:
		hud.show_aura_bonus(int(AURA_OVERTAKE_BONUS))
	# HUD update happens in _physics_process

# ============================================================================
# PERSISTENCE
# ============================================================================

func _save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"best_time_2000m": best_time_2000m
		}
		file.store_string(JSON.stringify(data))

func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY and "best_time_2000m" in data:
				best_time_2000m = data["best_time_2000m"]

# ============================================================================
# RACE FINISH & UTILITY
# ============================================================================

func _update_race_progress(delta: float) -> void:
	race_time += delta
	distance_traveled = player_position
	
	# Check for race finish
	if player_position >= TRACK_LENGTH:
		_finish_race("Player")
	else:
		for i in range(NUM_BOTS):
			if bot_positions[i] >= TRACK_LENGTH:
				_finish_race("Bot%d" % i)
				break

func _finish_race(winner_name: String) -> void:
	race_state = "finished"
	winner = winner_name
	
	# Save best time if player wins and it's their best
	if winner_name == "Player":
		if best_time_2000m == 0.0 or race_time < best_time_2000m:
			best_time_2000m = race_time
			_save_data()
	
	emit_signal("race_finished", winner)
	if hud:
		hud.show_race_complete(winner_name, player_rank, NUM_BOTS + 1)
		hud.update_best_time_display(best_time_2000m)

func _lane_to_x(lane: int) -> float:
	# Convert lane index to X position
	return -TRACK_WIDTH / 2.0 + LANE_WIDTH / 2.0 + float(lane) * LANE_WIDTH

func _x_to_lane(x: float) -> int:
	# Convert X position to lane index
	var normalized := (x + TRACK_WIDTH / 2.0) / TRACK_WIDTH
	return clampi(int(normalized * NUM_LANES), 0, NUM_LANES - 1)
