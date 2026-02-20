extends VehicleBody3D

# Car physics parameters

const MAX_BRAKE_FORCE = 3000.0
const MAX_REVERSE_FORCE = 5000.0
const MAX_STEER_ANGLE = 0.45
const STEER_SPEED = 2.0              # Snappy steering response
const HIGH_SPEED_STEER_REDUCTION = 0.5
const HIGH_SPEED_THRESHOLD = 55.0

@export var steering_multiplier: float = 1.0
@export var jump_multiplier: float = 1.0

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

var jump_count: int = 0
const MAX_JUMPS: int = 2
var jump_cooldown_timer: float = 0.0

# Camera variables
var camera_rotation_x: float = 0.0
var camera_rotation_y: float = 0.0
var camera_mode: String = "follow"

# References
@onready var camera_mount = $CameraMount
@onready var camera = $CameraMount/Camera3D
var ground_ray: RayCast3D
var driver_camera_node: Node3D
var camera_tween: Tween
var pov_weight: float = 0.0
var follow_cam_pos: Vector3

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
		follow_cam_pos = camera_mount.global_position
		# Force-snap camera immediately to prevent any white flash
		_force_snap_camera()

	driver_camera_node = Node3D.new()
	driver_camera_node.position = Vector3(0.2, 1.6, -0.2) 
	add_child(driver_camera_node)

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
	follow_cam_pos = target_position
	
	if driver_camera_node:
		camera_mount.global_position = follow_cam_pos.lerp(driver_camera_node.global_position, pov_weight)
	else:
		camera_mount.global_position = follow_cam_pos
		
	if camera:
		var follow_look = car_transform.origin + car_forward * 20.0
		# Driver looks slightly up and far ahead over the hood
		var driver_look = car_transform.origin + car_forward * 50.0 + Vector3.UP * 0.2
		var final_look = follow_look.lerp(driver_look, pov_weight)
		camera.look_at(final_look, Vector3.UP)

func _physics_process(delta):
	var velocity = linear_velocity
	current_speed_kmh = velocity.length() * 3.6
	
	# FIXED forward direction
	var forward_dir = -global_transform.basis.z
	var speed_along_forward = velocity.dot(forward_dir)
	if speed_along_forward < 0:
		current_speed_kmh = -current_speed_kmh
	
	emit_signal("speed_changed", current_speed_kmh)
	
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta
	
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
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return
	
	# --------------------------------------------------------------------------
	# STEERING - Responsive with progressive speed reduction
	# --------------------------------------------------------------------------
	var speed_factor = 1.0
	if abs(current_speed_kmh) > HIGH_SPEED_THRESHOLD:
		var speed_ratio = (abs(current_speed_kmh) - HIGH_SPEED_THRESHOLD) / HIGH_SPEED_THRESHOLD
		speed_factor = lerp(1.0, HIGH_SPEED_STEER_REDUCTION, min(speed_ratio, 1.0))
	
	steer_target = steer_input * MAX_STEER_ANGLE * speed_factor * steering_multiplier
	# Snappy steering: fast interpolation toward target, instant center return
	if abs(steer_input) < 0.1:
		# Quick return to center when no input
		steer_angle = lerp(steer_angle, 0.0, STEER_SPEED * 2.0 * steering_multiplier * delta)
	else:
		steer_angle = lerp(steer_angle, steer_target, STEER_SPEED * steering_multiplier * delta)
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
	if jump_input and jump_count < MAX_JUMPS and jump_cooldown_timer <= 0.0:
		# Jump height to cleanly clear another car
		var h_desired = 1
		var g = 9.81
		var v = sqrt(2 * g * h_desired)
		var impulse = mass * v * jump_multiplier
		
		# Cancel existing downward momentum if mid-air jumping
		if jump_count > 0 and linear_velocity.y < 0:
			var curr_vel = linear_velocity
			curr_vel.y = 0
			linear_velocity = curr_vel
		
		# Apply upward impulse
		apply_central_impulse(Vector3.UP * impulse)
		
		# Preserve forward momentum slightly during jump to not lose all speed
		var forward_dir = -global_transform.basis.z
		var forward_boost = abs(current_speed_kmh) * 5.0
		apply_central_impulse(forward_dir * mass * forward_boost * 0.01)
		
		is_grounded = false
		jump_count += 1
		jump_cooldown_timer = 0.1

func _check_grounded():
	# Raycast check is better than velocity
	if ground_ray and ground_ray.is_colliding():
		var dist = ground_ray.get_collision_point().distance_to(global_position)
		if dist < 2.0:
			is_grounded = true
			if jump_cooldown_timer <= 0.0:
				jump_count = 0
			return
	is_grounded = false

func _apply_air_stabilization(delta):
	if not is_grounded:
		# Auto-stabilize pitch and roll to land flat
		var current_up = global_transform.basis.y
		var world_up = Vector3.UP
		
		var error_up = current_up.cross(world_up)
		
		var stabilize_strength = 10000.0
		var damping_strength = 0.92
		
		if ground_ray and ground_ray.is_colliding():
			var dist = ground_ray.get_collision_point().distance_to(global_position)
			if dist < 4.0:
				stabilize_strength = 25000.0
				damping_strength = 0.85
		
		apply_torque(error_up * stabilize_strength)
		
		angular_velocity *= damping_strength
		
		angular_velocity.x = clamp(angular_velocity.x, -3.0, 3.0)
		angular_velocity.y = clamp(angular_velocity.y, -2.0, 2.0)
		angular_velocity.z = clamp(angular_velocity.z, -3.0, 3.0)

func _dampen_wall_contact(_delta):
	# Absorb wall impacts: kill lateral velocity AND all spinning when near edges
	# Track width is 20.8m, edges at ±10.4, walls at ±10.65
	var x_pos = global_position.x
	var abs_x = abs(x_pos)
	var track_half_width = 10.4  # TRACK_WIDTH / 2.0
	
	if abs_x > track_half_width - 0.1:  # Within 0.1m of the wall
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
	if event.is_action_pressed("toggle_camera") or (event is InputEventKey and event.keycode == KEY_C and event.pressed and not event.echo):
		if camera_mode == "follow":
			_switch_camera_mode("driver")
		else:
			_switch_camera_mode("follow")

func _switch_camera_mode(new_mode: String):
	camera_mode = new_mode
	if camera_tween:
		camera_tween.kill()
	camera_tween = create_tween()
	var target_weight = 1.0 if camera_mode == "driver" else 0.0
	camera_tween.tween_property(self, "pov_weight", target_weight, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func update_camera(delta):
	if not camera_mount:
		return
	
	var car_transform = global_transform
	var car_forward = -car_transform.basis.z
	
	# Follow cam ideal computations
	var ideal_follow_pos = car_transform.origin - car_forward * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
	follow_cam_pos = follow_cam_pos.lerp(ideal_follow_pos, CAMERA_FOLLOW_SPEED * delta)
	var follow_look = car_transform.origin + car_forward * 20.0
	
	# Driver cam computations
	var driver_pos = driver_camera_node.global_position if driver_camera_node else ideal_follow_pos
	var driver_look = car_transform.origin + car_forward * 50.0 + Vector3.UP * 0.2
	
	# Blend the two
	camera_mount.global_position = follow_cam_pos.lerp(driver_pos, pov_weight)
	var final_look = follow_look.lerp(driver_look, pov_weight)
	
	if camera:
		camera.look_at(final_look, Vector3.UP)
		
	camera_mount.rotation = Vector3.ZERO

func reset_car():
	global_transform.origin = Vector3(0, 2, 0)
	global_transform.basis = Basis()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	early_input_buffer.clear()
	distance_traveled = 0.0
	jump_count = 0
	is_grounded = false
	# Reset Engine Force
	max_engine_force = base_engine_force

func apply_speed_penalty_percent(percent: float):
	# Reduce max engine force by percentage (e.g. 0.4 reduces force by 40%)
	# Or set directly to (1.0 - percent) * base
	max_engine_force = base_engine_force * (1.0 - percent)
