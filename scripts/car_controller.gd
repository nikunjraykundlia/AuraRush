extends VehicleBody3D

# Car physics parameters
const MAX_ENGINE_FORCE = 67000.0
const MAX_BRAKE_FORCE = 5000.0
const MAX_REVERSE_FORCE = 15000.0
const MAX_STEER_ANGLE = 0.35
const STEER_SPEED = 2.5
const JUMP_FORCE = 6000.0
const HIGH_SPEED_STEER_REDUCTION = 0.5
const HIGH_SPEED_THRESHOLD = 80.0

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
var can_jump: bool = true

# Camera variables
var camera_rotation_x: float = 0.0
var camera_rotation_y: float = 0.0
var camera_mode: String = "follow"

# References
@onready var camera_mount = $CameraMount
@onready var camera = $CameraMount/Camera3D

# Track progress
var distance_traveled: float = 0.0

# Input Control
var input_enabled: bool = false
var early_input_buffer: Dictionary = {} # Stores last pressed state of actions

signal speed_changed(speed_kmh: float)

func _ready():
	pass

func _physics_process(delta):
	var velocity = linear_velocity
	current_speed_kmh = velocity.length() * 3.6
	
	# FIXED forward direction
	var forward_dir = -global_transform.basis.z
	var speed_along_forward = velocity.dot(forward_dir)
	if speed_along_forward < 0:
		current_speed_kmh = -current_speed_kmh
	
	emit_signal("speed_changed", current_speed_kmh)
	
	handle_input(delta)
	update_camera(delta)
	check_grounded()

func set_input_enabled(enabled: bool, flush_buffer: bool = false) -> void:
	input_enabled = enabled
	if enabled and flush_buffer:
		_process_buffered_input()

func _process_buffered_input() -> void:
	# Keep the throttle if it was pressed during countdown
	if early_input_buffer.get("accelerate", false):
		engine_force = -MAX_ENGINE_FORCE

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

	var speed_factor = 1.0
	if abs(current_speed_kmh) > HIGH_SPEED_THRESHOLD:
		var speed_ratio = (abs(current_speed_kmh) - HIGH_SPEED_THRESHOLD) / HIGH_SPEED_THRESHOLD
		speed_factor = lerp(1.0, HIGH_SPEED_STEER_REDUCTION, min(speed_ratio, 1.0))
	
	steer_target = steer_input * MAX_STEER_ANGLE * speed_factor
	steer_angle = lerp(steer_angle, steer_target, STEER_SPEED * delta)
	steering = steer_angle
	
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
		engine_force = -throttle_input * MAX_ENGINE_FORCE
		brake = 0
	
	if jump_input and can_jump:
		apply_central_impulse(Vector3.UP * JUMP_FORCE)
		can_jump = false

func _input(event):
	if event.is_action_pressed("toggle_camera"):
		if camera_mode == "follow":
			camera_mode = "mouse"
			camera_rotation_x = 0.0
			camera_rotation_y = 0.0
		else:
			camera_mode = "follow"
	
	if camera_mode == "mouse" and event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		camera_rotation_y -= event.relative.x * MOUSE_SENSITIVITY
		camera_rotation_x = clamp(camera_rotation_x, -PI/3, PI/6)

func update_camera(delta):
	if not camera_mount:
		return
	
	if camera_mode == "follow":
		var car_transform = global_transform
		
		# FIXED forward direction
		var car_forward = -car_transform.basis.z
		
		var target_position = car_transform.origin - car_forward * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
		camera_mount.global_position = camera_mount.global_position.lerp(target_position, CAMERA_FOLLOW_SPEED * delta)
		
		if camera:
			var look_target = car_transform.origin + car_forward * 20.0
			camera.look_at(look_target, Vector3.UP)
		
		camera_mount.rotation = Vector3.ZERO
	else:
		var target_rotation = Vector3(camera_rotation_x, camera_rotation_y, 0)
		camera_mount.rotation = camera_mount.rotation.lerp(target_rotation, CAMERA_SMOOTH * delta)
		
		var target_position = Vector3(0, 3, -6)
		camera_mount.position = camera_mount.position.lerp(target_position, CAMERA_SMOOTH * delta)

func check_grounded():
	if abs(linear_velocity.y) < 0.5:
		can_jump = true

func reset_car():
	global_transform.origin = Vector3(0, 2, 0)
	global_transform.basis = Basis()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	early_input_buffer.clear()