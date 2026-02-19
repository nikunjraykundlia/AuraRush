extends Node3D

# ============================================================================
# AURA RUSH - Straight Track Racing with Aura Collection System
# ============================================================================

# --- Race Configuration ---
const NUM_BOTS := 3
const TRACK_LENGTH := 3000.0          # Finish line distance in meters
const TRACK_WIDTH := 16.0             # Lane width
const NUM_LANES := 4                  # Number of driving lanes
const LANE_WIDTH := TRACK_WIDTH / NUM_LANES

# --- Aura System Configuration ---
const AURA_BOOST_REFERENCE := 100.0    # Reference point for boost strength scaling
const AURA_BURST_DURATION := 3.0
const AURA_BURST_SPEED_MULT := 1.45
const AURA_ORB_VALUE := 5.0
const AURA_DRIFT_RATE := 2.0          # Aura per second while drifting
const AURA_OVERTAKE_BONUS := 10.0
const AURA_PROXIMITY_RATE := 1.0      # Aura per second near opponents
const AURA_COLLISION_PENALTY := 15.0
const AURA_OFFTRACK_DRAIN := 3.0      # Aura drain per second off-track

# --- Aura Boost Configuration ---
const AURA_BOOST_DURATION := 2.0      # Boost lasts 2 seconds
const AURA_BOOST_BASE_FORCE := 15000.0  # Base boost force
const AURA_BOOST_MAX_FORCE := 50000.0   # Max boost force at full aura

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
var highest_aura: float = 0.0          # All-time highest aura (persisted)

# --- Aura Boost State ---
var aura_boost_active: bool = false
var aura_boost_timer: float = 0.0
var aura_boost_force: float = 0.0     # Current boost force strength

# --- Bot State ---
var bot_bodies: Array[RigidBody3D] = []
var bot_meshes: Array[MeshInstance3D] = []
var bot_positions: Array[float] = []   # Distance along track
var bot_lanes: Array[int] = []
var bot_speeds: Array[float] = []
var bot_lane_change_timers: Array[float] = []
var bot_current_x: Array[float] = [] 
var bot_wheel_nodes: Array = []        # Array of arrays - each bot has 4 wheel Node3Ds
var bot_push_offset_x: Array[float] = []  # Collision push offset (X axis)
var bot_push_offset_z: Array[float] = []  # Collision push offset (Z axis)
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

# Preloaded 3D car model scenes
var _car_body_scene: PackedScene = null
var _car_wheel_scene: PackedScene = null

func _ready() -> void:
	randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Preload 3D car model
	_car_body_scene = load("res://assests/models/Doge/doge-body.glb")
	_car_wheel_scene = load("res://assests/models/Doge/Wheel.glb")
	
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
		hud.update_highest_aura_display(highest_aura)
		hud.update_aura(aura_meter)
		hud.update_rank(1, NUM_BOTS + 1)
	
	# 1. Apply 3D car model to Player Car Body
	var player_mesh_node = player_body.get_node_or_null("MeshInstance3D")
	if player_mesh_node:
		player_mesh_node.queue_free() # Remove the placeholder box
	
	# Create 3D model visuals for player (cyan neon color)
	var player_car_visuals = _create_3d_car_model(Color(0.0, 0.96, 1.0), false)
	player_car_visuals.name = "CarVisuals"
	player_body.add_child(player_car_visuals)
	
	# 2. Apply Neon Shader to Player Wheels
	var wheel_mat = _create_neon_material(Color(0.0, 0.96, 1.0))
	for wheel_name in ["FrontLeftWheel", "FrontRightWheel", "RearLeftWheel", "RearRightWheel"]:
		var wheel_node = player_body.get_node_or_null(wheel_name)
		if wheel_node:
			# Remove the old cylinder mesh
			var old_mesh = wheel_node.get_node_or_null("MeshInstance3D")
			if old_mesh:
				old_mesh.queue_free()
			# Add 3D wheel model
			if _car_wheel_scene:
				var wheel_model = _car_wheel_scene.instantiate()
				wheel_model.name = "WheelModel"
				wheel_model.scale = Vector3(0.9, 0.9, 0.9)
				_apply_neon_to_model(wheel_model, Color(0.0, 0.96, 1.0))
				wheel_node.add_child(wheel_model)
	
	# Smooth start: wait for scene to fully initialize, then start countdown
	# Use call_deferred to avoid first-frame visual pop
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
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
			divider.mesh.material = _create_simple_neon_material(Color(1.0, 1.0, 1.0, 0.6))
			add_child(divider)
		
		# Track edge barriers (neon) - Soft walls to prevent hard bouncing
		for side in [-1, 1]:
			var barrier_body := StaticBody3D.new()
			# Soft, absorbent barrier to minimize reaction force
			var friction_mat := PhysicsMaterial.new()
			friction_mat.friction = 0.0  # Zero friction so car slides along
			friction_mat.bounce = 0.0    # Zero bounce to prevent bouncing back
			friction_mat.absorbent = true # Absorb impact energy
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
			barrier_mesh.mesh.material = _create_simple_neon_material(barrier_color)
			barrier_body.add_child(barrier_mesh)

	# ---- FINISH LINE at 3000m ----
	# Visual finish line on the ground
	var finish_line = MeshInstance3D.new()
	finish_line.mesh = BoxMesh.new()
	finish_line.mesh.size = Vector3(TRACK_WIDTH + 1.0, 0.15, 3.0)
	finish_line.position = Vector3(0, 0.08, 3000.0)
	
	# Checkerboard-style neon finish material
	var finish_mat = StandardMaterial3D.new()
	finish_mat.albedo_color = Color(1.0, 1.0, 1.0)
	finish_mat.emission_enabled = true
	finish_mat.emission = Color(1.0, 1.0, 1.0)
	finish_mat.emission_energy_multiplier = 5.0
	finish_line.mesh.material = finish_mat
	add_child(finish_line)
	
	# Finish line arch / gate (two pillars + top bar)
	for side in [-1, 1]:
		var pillar = MeshInstance3D.new()
		pillar.mesh = BoxMesh.new()
		pillar.mesh.size = Vector3(0.5, 8.0, 0.5)
		pillar.position = Vector3(side * (TRACK_WIDTH / 2.0 + 0.5), 4.0, 3000.0)
		pillar.mesh.material = _create_simple_neon_material(Color(1.0, 0.84, 0.0))  # Gold
		add_child(pillar)
	
	var top_bar = MeshInstance3D.new()
	top_bar.mesh = BoxMesh.new()
	top_bar.mesh.size = Vector3(TRACK_WIDTH + 1.5, 0.5, 0.5)
	top_bar.position = Vector3(0, 8.0, 3000.0)
	top_bar.mesh.material = _create_simple_neon_material(Color(1.0, 0.84, 0.0))  # Gold
	add_child(top_bar)
	
	# "FINISH" text indicators on each side
	for side in [-1, 1]:
		var flag = MeshInstance3D.new()
		flag.mesh = BoxMesh.new()
		flag.mesh.size = Vector3(0.1, 2.0, 1.5)
		flag.position = Vector3(side * (TRACK_WIDTH / 2.0 + 0.8), 6.0, 3000.0)
		var flag_mat = _create_simple_neon_material(Color(0.0, 1.0, 0.0))  # Green glow
		flag.mesh.material = flag_mat
		add_child(flag)

	# End Wall at 3100m (stop wall beyond finish line)
	var end_wall_body = StaticBody3D.new()
	var end_wall_friction = PhysicsMaterial.new()
	end_wall_friction.friction = 0.5
	end_wall_friction.bounce = 0.0
	end_wall_friction.absorbent = true
	end_wall_body.physics_material_override = end_wall_friction
	end_wall_body.position = Vector3(0, 10, 3100.0)  # Stop wall 100m past finish
	add_child(end_wall_body)
	
	var ec = CollisionShape3D.new()
	ec.shape = BoxShape3D.new()
	ec.shape.size = Vector3(TRACK_WIDTH * 3, 40, 5)
	end_wall_body.add_child(ec)
	
	var em = MeshInstance3D.new()
	em.mesh = BoxMesh.new()
	em.mesh.size = Vector3(TRACK_WIDTH * 3, 40, 5)
	em.mesh.material = _create_simple_neon_material(Color(0.0, 0.96, 1.0)) # Cyan neon (matches edge wall)
	end_wall_body.add_child(em)

func _setup_bots() -> void:
	var bot_colors: Array[Color] = [
		Color(1.0, 0.15, 0.49),  # Pink
		Color(1.0, 0.85, 0.0),   # Yellow
		Color(0.0, 1.0, 0.4)     # Green
	]
	
	for i in range(NUM_BOTS):
		var bot := RigidBody3D.new()
		bot.mass = 600.0           # Lighter than player so they get pushed
		bot.name = "Bot%d" % i
		bot.gravity_scale = 0.0
		bot.lock_rotation = true
		# Make bots not apply strong forces back to the player
		var bot_phys = PhysicsMaterial.new()
		bot_phys.friction = 0.0
		bot_phys.bounce = 0.0
		bot_phys.absorbent = true
		bot.physics_material_override = bot_phys
		
		# Staggered start positions
		var bot_lane := (i + 2) % NUM_LANES
		var bot_x := _lane_to_x(bot_lane)
		var bot_z := 5.0 - float(i + 1) * 3.0  # Staggered behind player relative to 0
		bot.position = Vector3(bot_x, 0.4, bot_z)
		bot.rotation_degrees.y = 180.0
		add_child(bot)
		bot_bodies.append(bot)
		
		# Use 3D car model for bots with their neon color
		var bot_visuals = _create_3d_car_model(bot_colors[i], true)
		bot_visuals.position = Vector3(0, 0, 0) 
		bot.add_child(bot_visuals)
		
		# Collect wheel node references for spinning animation
		var wheels: Array[Node3D] = []
		for wi in range(4):
			var wnode = bot_visuals.get_node_or_null("BotWheel_%d" % wi)
			if wnode:
				wheels.append(wnode)
		bot_wheel_nodes.append(wheels)
		
		# Bot collision
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 1.0, 4.0)
		collision.shape = shape
		bot.add_child(collision)
		
		# Initialize bot state
		bot_positions.append(bot_z)
		bot_lanes.append(bot_lane)
		# Randomize bot speed widely so winner is unpredictable each race
		var speed = randf_range(35.0, 58.0)
		bot_speeds.append(speed)
		bot_lane_change_timers.append(0.0)
		bot_current_x.append(bot_x)
		bot_push_offset_x.append(0.0)
		bot_push_offset_z.append(0.0)
	
	if hud:
		hud.init_minimap_markers(bot_colors)

func _setup_aura_orbs() -> void:
	# Spawn aura orbs along the track (30% less frequent = 30% larger spacing)
	var orb_spacing := 57.0  # Was 40.0, increased by ~43% to get 30% fewer orbs
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

const NEON_CAR_SHADER = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_color : source_color;
uniform float emission_strength : hint_range(0.0, 20.0) = 3.0; // Increased punch
uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	// Dark metallic body base
	vec3 body_color = albedo_color * 0.05; 
	ALBEDO = body_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	// Fresnel Edge Glow (The "Neon" look)
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 2.5);
	vec3 edge_glow = albedo_color * fresnel * emission_strength;
	
	// Pulsating inner core effect (subtle)
	float pulse = 0.5 + 0.5 * sin(TIME * 3.0);
	vec3 inner_glow = albedo_color * 0.2 * pulse;
	
	EMISSION = edge_glow + inner_glow;
}
"""

func _create_neon_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = NEON_CAR_SHADER
	mat.shader = shader
	mat.set_shader_parameter("albedo_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("emission_strength", 4.0)
	return mat

func _create_simple_neon_material(color: Color) -> StandardMaterial3D:
	# Fallback/Simple material if needed, or for static objects like barriers
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	return mat

func _create_track_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.08) # Darker track to pop neon
	mat.roughness = 0.6
	mat.metallic = 0.3
	return mat

func _create_aura_orb_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.96, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.96, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

# Renamed original neon material function to distinguish usage
# _create_neon_material is now the specialized Car Shader


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

var flipped_alert_timer: float = 0.0

# ... (existing vars)

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
		_check_player_flipped(delta)

func _check_player_flipped(delta: float) -> void:
	if not player_body: return
	
	# Check if car's up vector is pointing somewhat down or sideways (dot product with World Up)
	# 0.4 means it's tilted more than ~65 degrees from upright
	if player_body.global_transform.basis.y.dot(Vector3.UP) < 0.4:
		flipped_alert_timer += delta
		if flipped_alert_timer > 1.5: # 1.5 seconds threshold
			_reset_car_orientation()
			flipped_alert_timer = 0.0
	else:
		flipped_alert_timer = 0.0

func _reset_car_orientation() -> void:
	if not player_body: return
	
	var current_pos = player_body.global_position
	
	# Reset orientation and place car at exact center of track (X=0), lift slightly
	player_body.linear_velocity = Vector3.ZERO
	player_body.angular_velocity = Vector3.ZERO
	player_body.global_position = Vector3(0.0, current_pos.y + 1.0, current_pos.z)
	player_body.rotation_degrees = Vector3(0, 180, 0) # Face forward
	
	if hud:
		hud.show_recover_alert()
		get_tree().create_timer(1.0).timeout.connect(func(): hud.hide_recover_alert())

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
	
	# Aura speed boost timer & application
	if aura_boost_active:
		aura_boost_timer -= delta
		if aura_boost_timer <= 0.0:
			aura_boost_active = false
			aura_boost_force = 0.0
		else:
			# Apply forward boost force to player car
			_apply_aura_boost(delta)

func _apply_aura_boost(delta: float) -> void:
	"""Apply forward impulse to player car based on current aura boost."""
	if not player_body:
		return
	var forward_dir = -player_body.global_transform.basis.z
	# Fade out boost over time (stronger at start, weaker near end)
	var fade = aura_boost_timer / AURA_BOOST_DURATION
	var force = aura_boost_force * fade
	player_body.apply_central_force(forward_dir * force)

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
	
	# Time Bonus: Reduce current race time by 0.1s
	var time_bonus = 0.1
	race_time = maxf(race_time - time_bonus, 0.0)
	
	# --- AURA SPEED BOOST ---
	# The more aura you have, the stronger the boost
	# Boost scales based on aura_meter (no cap, stronger as aura grows)
	var aura_ratio = aura_meter / AURA_BOOST_REFERENCE  # Can exceed 1.0
	aura_boost_force = lerp(AURA_BOOST_BASE_FORCE, AURA_BOOST_MAX_FORCE, min(aura_ratio, 3.0))
	aura_boost_timer = AURA_BOOST_DURATION
	aura_boost_active = true
	
	orb.visible = false
	if hud:
		hud.pulse_aura_display()

func _add_aura(amount: float) -> void:
	aura_meter += amount  # No cap - aura grows infinitely
	# Track highest aura achieved
	if aura_meter > highest_aura:
		highest_aura = aura_meter

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
		
		# Update bot position (Smooth lane change)
		var target_x := _lane_to_x(bot_lanes[i])
		var prev_x = bot_current_x[i]
		bot_current_x[i] = lerpf(bot_current_x[i], target_x, 5.0 * delta)
		
		# Calculate banking (roll) based on lateral movement
		var lateral_speed = (bot_current_x[i] - prev_x) / delta
		var target_roll = clamp(lateral_speed * -0.05, -0.2, 0.2)
		var current_rot = bot.rotation.z
		bot.rotation.z = lerpf(current_rot, target_roll, 5.0 * delta)
		
		# Recover push offsets over time (bots drift back to their AI path)
		bot_push_offset_x[i] = lerpf(bot_push_offset_x[i], 0.0, 2.0 * delta)
		bot_push_offset_z[i] = lerpf(bot_push_offset_z[i], 0.0, 1.5 * delta)
		
		# Clamp push offsets so bots don't fly off track
		bot_push_offset_x[i] = clampf(bot_push_offset_x[i], -6.0, 6.0)
		bot_push_offset_z[i] = clampf(bot_push_offset_z[i], -15.0, 15.0)
		
		var final_x = bot_current_x[i] + bot_push_offset_x[i]
		# Keep bot within track bounds
		final_x = clampf(final_x, -(TRACK_WIDTH / 2.0 - 1.0), TRACK_WIDTH / 2.0 - 1.0)
		
		var current_z = bot_positions[i] + bot_push_offset_z[i]
		bot.position = Vector3(final_x, 0.4, current_z)
		
		# Spin bot wheels based on speed
		if i < bot_wheel_nodes.size():
			var wheel_spin_speed = bot_speeds[i] * 2.0  # radians per second
			for wheel_node in bot_wheel_nodes[i]:
				if wheel_node:
					wheel_node.rotation.x += wheel_spin_speed * delta
	
	# Check player-bot collisions and apply proper push physics
	_handle_player_bot_collisions(delta)

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

func _handle_player_bot_collisions(_delta: float) -> void:
	"""Detect player-bot proximity and apply proper push physics."""
	if not player_body:
		return
	
	var hit_radius := 3.0  # Distance at which we consider a collision
	var player_vel := player_body.linear_velocity
	var player_speed := player_vel.length()
	
	for i in range(NUM_BOTS):
		var bot := bot_bodies[i]
		var to_bot := bot.global_position - player_body.global_position
		var dist := to_bot.length()
		
		if dist < hit_radius and player_speed > 3.0:
			# Normalize direction from player to bot
			var push_dir := to_bot.normalized()
			
			# Calculate push strength based on player speed
			var push_strength := player_speed * 0.15  # Scale factor
			
			# Push the bot away in the direction of impact
			bot_push_offset_x[i] += push_dir.x * push_strength
			bot_push_offset_z[i] += push_dir.z * push_strength
			
			# Also add forward push if player is moving fast (rear-end collision)
			var forward_component = player_vel.dot(Vector3(0, 0, 1))
			if abs(forward_component) > 5.0:
				bot_push_offset_z[i] += sign(forward_component) * abs(forward_component) * 0.08
			
			# Dampen player velocity on impact (soft collision, not violent)
			# Keep most forward speed, reduce lateral and stop spin
			player_body.linear_velocity *= 0.6   # Lose 40% speed on impact
			player_body.angular_velocity = Vector3.ZERO  # No spinning

# ============================================================================
# COLLISION & RANKING
# ============================================================================

func _check_collisions() -> void:
	var collision_radius := 2.5
	
	for i in range(NUM_BOTS):
		var bot := bot_bodies[i]
		var dist := player_body.position.distance_to(bot.position)
		
		if dist < collision_radius:
			# Collision penalty (aura only)
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
			"best_time_2000m": best_time_2000m,
			"highest_aura": highest_aura
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
			if typeof(data) == TYPE_DICTIONARY:
				if "best_time_2000m" in data:
					best_time_2000m = data["best_time_2000m"]
				if "highest_aura" in data:
					highest_aura = data["highest_aura"]

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
	
	# Always save data (highest aura is tracked regardless of winner)
	_save_data()
	
	emit_signal("race_finished", winner)
	if hud:
		hud.show_race_complete(winner_name, player_rank, NUM_BOTS + 1)
		hud.update_best_time_display(best_time_2000m)
		hud.update_highest_aura_display(highest_aura)

func _lane_to_x(lane: int) -> float:
	# Convert lane index to X position
	return -TRACK_WIDTH / 2.0 + LANE_WIDTH / 2.0 + float(lane) * LANE_WIDTH

func _x_to_lane(x: float) -> int:
	# Convert X position to lane index
	var normalized := (x + TRACK_WIDTH / 2.0) / TRACK_WIDTH
	return clampi(int(normalized * NUM_LANES), 0, NUM_LANES - 1)

# ============================================================================
# 3D CAR MODEL SYSTEM
# ============================================================================

func _create_3d_car_model(color: Color, with_wheels: bool) -> Node3D:
	"""Create a 3D car model using the imported GLB, with neon color overlay."""
	var root = Node3D.new()
	
	# Load and instantiate the 3D car body
	if _car_body_scene:
		var body_model = _car_body_scene.instantiate()
		body_model.name = "BodyModel"
		# The doge model in the demo was rotated 180 degrees (Transform has -1 on X and Z)
		# Match that rotation so it faces +Z (forward in our track)
		body_model.rotation_degrees.y = 180.0
		body_model.scale = Vector3(1.0, 1.0, 1.0)
		body_model.position = Vector3(0, 0.3, 0)
		
		# Apply neon color shader to all mesh surfaces in the model
		_apply_neon_to_model(body_model, color)
		
		root.add_child(body_model)
	else:
		# Fallback: simple box if model can't load
		var fallback = MeshInstance3D.new()
		fallback.mesh = BoxMesh.new()
		fallback.mesh.size = Vector3(1.6, 0.5, 4.2)
		fallback.position = Vector3(0, 0.35, 0)
		fallback.mesh.material = _create_neon_material(color)
		root.add_child(fallback)
	
	# Add wheels for bots (player uses VehicleWheel3D physics wheels)
	if with_wheels and _car_wheel_scene:
		# Wheel positions: Y=0 so tires sit on the ground relative to the bot body
		var wheel_positions = [
			Vector3(-1.0, 0.0, 1.3),    # Front Left
			Vector3(1.0, 0.0, 1.3),     # Front Right
			Vector3(-1.0, 0.0, -1.3),   # Rear Left
			Vector3(1.0, 0.0, -1.3)     # Rear Right
		]
		var wheel_idx = 0
		for pos in wheel_positions:
			var wheel_model = _car_wheel_scene.instantiate()
			wheel_model.name = "BotWheel_%d" % wheel_idx
			wheel_model.scale = Vector3(0.9, 0.9, 0.9)
			wheel_model.position = pos
			_apply_neon_to_model(wheel_model, color)
			root.add_child(wheel_model)
			wheel_idx += 1
	elif with_wheels:
		# Fallback cylinder wheels if model can't load
		var material = _create_neon_material(color)
		var wheel_positions = [
			Vector3(-0.95, 0.0, 1.3),
			Vector3(0.95, 0.0, 1.3),
			Vector3(-0.95, 0.0, -1.3),
			Vector3(0.95, 0.0, -1.3)
		]
		var wheel_idx = 0
		for pos in wheel_positions:
			var w = MeshInstance3D.new()
			w.name = "BotWheel_%d" % wheel_idx
			w.mesh = CylinderMesh.new()
			w.mesh.height = 0.35
			w.mesh.top_radius = 0.4
			w.mesh.bottom_radius = 0.4
			w.rotation_degrees.z = 90
			w.position = pos
			w.mesh.material = material
			root.add_child(w)
			wheel_idx += 1
	
	return root

func _apply_neon_to_model(node: Node, color: Color) -> void:
	"""Recursively apply neon shader material to all MeshInstance3D nodes in a model."""
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var neon_mat = _create_neon_material(color)
		# Apply to material override so it covers all surfaces
		mesh_inst.material_override = neon_mat
	
	# Recurse into children
	for child in node.get_children():
		_apply_neon_to_model(child, color)
