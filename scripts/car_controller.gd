extends VehicleBody3D

# Car physics parameters

const MAX_BRAKE_FORCE = 3000.0
const MAX_REVERSE_FORCE = 5000.0
const MAX_STEER_ANGLE = 0.35
const STEER_SPEED = 1.5              # Snappy steering response
const JUMP_FORCE = 4000.0             # Lower base jump for smoother arcs
const HIGH_SPEED_STEER_REDUCTION = 0.5
const HIGH_SPEED_THRESHOLD = 55.0

var max_engine_force = 20000.0
var base_engine_force = 15000.0

# Camera control
const MOUSE_SENSITIVITY = 0.002
const CAMERA_SMOOTH = 5.0
const CAMERA_FOLLOW_SPEED = 8.0
const CAMERA_HEIGHT = 4.0
const CAMERA_DISTANCE = 8.0

# State variables
var current_speed_kmh: float = 0.0
var steer_target: float = 0.0
var steer_angle: float = 0.0
var is_grounded: bool = true   # Updated via RayCast

# Camera variables
var camera_rotation_x: float = 0.0
var camera_rotation_y: float = 0.0
var camera_mode: String = "follow"

# References
@onready var camera_mount = $CameraMount
@onready var camera = $CameraMount/Camera3D
var ground_ray: RayCast3D

# Track progress
var distance_traveled: float = 0.0

# Input Control
var input_enabled: bool = false
var early_input_buffer: Dictionary = {} # Stores last pressed state of actions

# Smooth start - force camera snap for first few frames to avoid white flash
var _init_frames: int = 0
const INIT_SNAP_FRAMES: int = 5

signal speed_changed(speed_kmh: float)

func _ready():
	# Detach camera mount from car parent to allow smooth independent movement
	if camera_mount:
		camera_mount.set_as_top_level(true)
		
		# Force-snap camera immediately to prevent any white flash
		_force_snap_camera()

	# Setup Ground Raycast
	ground_ray = RayCast3D.new()
	ground_ray.position = Vector3(0, 0.5, 0) # Start slightly above center
	ground_ray.target_position = Vector3(0, -1.0, 0) # Cast down
	ground_ray.enabled = true
	add_child(ground_ray)
	
	# Also snap on deferred to catch post-ready positioning
	call_deferred("_force_snap_camera")

func _force_snap_camera() -> void:
	"""Instantly teleport camera to correct position - no interpolation."""
	if not camera_mount:
		return
	var car_transform = global_transform
	var car_forward = -car_transform.basis.z
	var target_position = car_transform.origin - car_forward * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
	camera_mount.global_position = target_position
	if camera:
		var look_target = car_transform.origin + car_forward * 20.0
		camera.look_at(look_target, Vector3.UP)

func _physics_process(delta):
	var velocity = linear_velocity
	current_speed_kmh = velocity.length() * 3.6
	
	# FIXED forward direction
	var forward_dir = -global_transform.basis.z
	var speed_along_forward = velocity.dot(forward_dir)
	if speed_along_forward < 0:
		current_speed_kmh = -current_speed_kmh
	
	emit_signal("speed_changed", current_speed_kmh)
	
	# Force-snap camera for first few frames to prevent white flash at game start
	if _init_frames < INIT_SNAP_FRAMES:
		_init_frames += 1
		_force_snap_camera()
	
	_check_grounded()
	handle_input(delta)
	update_camera(delta)
	_apply_air_stabilization(delta)
	_dampen_wall_contact(delta)

func set_input_enabled(enabled: bool, flush_buffer: bool = false) -> void:
	input_enabled = enabled
	if enabled and flush_buffer:
		_process_buffered_input()

func _process_buffered_input() -> void:
	# Keep the throttle if it was pressed during countdown
	if early_input_buffer.get("accelerate", false):
		engine_force = -max_engine_force

func handle_input(delta):
	# FIXED steering axis order
	var steer_input = Input.get_axis("steer_left", "steer_right")
	var throttle_input = Input.get_action_strength("accelerate")
	var brake_input_val = Input.get_action_strength("brake")
	var jump_input = Input.is_action_just_pressed("jump")
	
	if not input_enabled:
		# Buffer inputs during countdown
		if throttle_input > 0: early_input_buffer["accelerate"] = true
		else: early_input_buffer.erase("accelerate")
		
		# Lock physics controls
		engine_force = 0
		brake = MAX_BRAKE_FORCE # Hold brake while locked
		steering = 0
		return
	
	# --------------------------------------------------------------------------
	# STEERING - Responsive with progressive speed reduction
	# --------------------------------------------------------------------------
	var speed_factor = 1.0
	if abs(current_speed_kmh) > HIGH_SPEED_THRESHOLD:
		var speed_ratio = (abs(current_speed_kmh) - HIGH_SPEED_THRESHOLD) / HIGH_SPEED_THRESHOLD
		speed_factor = lerp(1.0, HIGH_SPEED_STEER_REDUCTION, min(speed_ratio, 1.0))
	
	steer_target = steer_input * MAX_STEER_ANGLE * speed_factor
	# Snappy steering: fast interpolation toward target, instant center return
	if abs(steer_input) < 0.1:
		# Quick return to center when no input
		steer_angle = lerp(steer_angle, 0.0, STEER_SPEED * 2.0 * delta)
	else:
		steer_angle = lerp(steer_angle, steer_target, STEER_SPEED * delta)
	steering = steer_angle
	
	# --------------------------------------------------------------------------
	# ENGINE & BRAKES (Works on ground or air - wheels spin in air)
	# --------------------------------------------------------------------------
	if brake_input_val > 0:
		if current_speed_kmh > 5.0:
			engine_force = 0
			# Apply brake proportional to input, but smoother
			brake = brake_input_val * MAX_BRAKE_FORCE
		else:
			# Reverse logic
			engine_force = brake_input_val * MAX_REVERSE_FORCE
			brake = 0
	else:
		# Forward
		engine_force = -throttle_input * max_engine_force
		brake = 0
	
	# --------------------------------------------------------------------------
	# AIR CONTROL (Additional mid-air stabilization/control)
	# --------------------------------------------------------------------------
	if not is_grounded:
		# Allow mid-air rotation for landing
		if steer_input != 0:
			angular_velocity.y -= steer_input * delta * 2.0
			# Bank slightly
			angular_velocity.z -= steer_input * delta * 1.5

	# --------------------------------------------------------------------------
	# JUMP SYNCHRONIZATION
	# --------------------------------------------------------------------------
	if jump_input and is_grounded:
		# Smooth jump: gentle upward arc that scales mildly with speed
		var speed_bonus = abs(current_speed_kmh) * 10.0  # Gentler scaling
		var total_jump_force = JUMP_FORCE + speed_bonus
		
		# Cap so high-speed jumps don't launch into orbit
		total_jump_force = min(total_jump_force, 8000.0)
		
		# Apply upward impulse
		apply_central_impulse(Vector3.UP * total_jump_force)
		
		# Preserve forward momentum during jump for smooth arc
		var forward_dir = -global_transform.basis.z
		var forward_boost = abs(current_speed_kmh) * 5.0
		apply_central_impulse(forward_dir * forward_boost)
		
		is_grounded = false # Prevent double jumps immediately

func _check_grounded():
	# Raycast check is better than velocity
	if ground_ray and ground_ray.is_colliding():
		is_grounded = true
	else:
		# Fallback: if raycast misses but we are not moving vertically much, we might be grounded
		# This helps if the raycast length (1.5m dowwn) is too short for some reason (suspension extension)
		is_grounded = abs(linear_velocity.y) < 1.0

func _apply_air_stabilization(delta):
	if not is_grounded:
		# Auto-stabilize pitch and roll to land flat
		var current_rot = global_rotation
		
		# Apply corrective torque if we are tilting too much
		var correction_x = -current_rot.x * 2000.0
		var correction_z = -current_rot.z * 2000.0
		
		apply_torque(global_transform.basis.x * correction_x * delta)
		apply_torque(global_transform.basis.z * correction_z * delta)

func _dampen_wall_contact(_delta):
	# Absorb wall impacts: kill lateral velocity AND all spinning when near edges
	# Track width is 16m, edges at ±8.0, walls at ±8.25
	var x_pos = global_position.x
	var abs_x = abs(x_pos)
	var track_half_width = 8.0  # TRACK_WIDTH / 2.0
	
	if abs_x > track_half_width - 0.5:  # Within 0.5m of the wall
		# 1. Kill lateral (X) velocity almost completely — wall absorbs the hit
		linear_velocity.x *= 0.05  # Keep only 5%
		
		# 2. Kill ALL angular velocity — no spinning at all on wall contact
		angular_velocity = Vector3.ZERO
		
		# 3. Force the yaw rotation to stay straight (facing forward)
		# Smoothly correct any yaw deviation caused by the impact
		var current_yaw = rotation_degrees.y
		# The car should face 180 degrees (forward along +Z)
		var yaw_error = wrapf(current_yaw - 180.0, -180.0, 180.0)
		if abs(yaw_error) > 2.0:  # More than 2 degrees off
			rotation_degrees.y = lerpf(current_yaw, 180.0, 0.3)
		
		# 4. Gentle push back toward center to prevent sticking to wall
		var push_direction = -sign(x_pos)  # Push toward center
		linear_velocity.x += push_direction * 2.0  # Gentle inward nudge

func _input(event):
	if event.is_action_pressed("toggle_camera"):
		if camera_mode == "follow":
			camera_mode = "driver"
		else:
			camera_mode = "follow"

func update_camera(delta):
	if not camera_mount:
		return
	
	var car_transform = global_transform
	var car_forward = -car_transform.basis.z
	
	if camera_mode == "follow":
		# Chase cam: behind and above the car
		var target_position = car_transform.origin - car_forward * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
		camera_mount.global_position = camera_mount.global_position.lerp(target_position, CAMERA_FOLLOW_SPEED * delta)
		
		if camera:
			var look_target = car_transform.origin + car_forward * 20.0
			camera.look_at(look_target, Vector3.UP)
		
		camera_mount.rotation = Vector3.ZERO
	
	elif camera_mode == "driver":
		# Driver POV: inside the car, looking forward
		var driver_pos = car_transform.origin + car_forward * 0.5 + Vector3.UP * 1.2
		camera_mount.global_position = camera_mount.global_position.lerp(driver_pos, 15.0 * delta)
		
		if camera:
			var look_target = car_transform.origin + car_forward * 50.0 + Vector3.UP * 0.8
			camera.look_at(look_target, Vector3.UP)
		
		camera_mount.rotation = Vector3.ZERO

func reset_car():
	global_transform.origin = Vector3(0, 2, 0)
	global_transform.basis = Basis()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	early_input_buffer.clear()
	# Reset Engine Force
	max_engine_force = base_engine_force

func apply_speed_penalty_percent(percent: float):
	# Reduce max engine force by percentage (e.g. 0.4 reduces force by 40%)
	# Or set directly to (1.0 - percent) * base
	max_engine_force = base_engine_force * (1.0 - percent)
