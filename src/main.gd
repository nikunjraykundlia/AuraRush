extends Node3D

const NUM_BOTS := 3
const TRACK_LEN := 950.0 # Length of straight track
const SEG_LEN := 120.0   # Length of each segment
const NUM_SEGMENTS := int(TRACK_LEN / SEG_LEN)

# --- Track setup ---
var track_segments: Array = []

# --- Car setups ---
var car_body: RigidBody3D
var bot_bodies: Array[RigidBody3D] = []
var car_mesh: MeshInstance3D
var bot_meshes: Array[MeshInstance3D] = []

# --- Input config ---
var steering: float = 0.0
var throttle: float = 0.0
var max_speed: float = 42.0
var accel: float = 23.0
var turn_rate: float = 1.2

# --- Bot AI ---
var bot_speed: Array[float] = [40.2, 39.6, 41.3] # Slight randomness per bot

# --- Race state ---
var race_started: bool = false
var finished: bool = false
var winner: String = ""
var player_cam: Camera3D

func _ready() -> void:
	# Straight track on Z axis
	for i in range(NUM_SEGMENTS):
		var seg := MeshInstance3D.new()
		seg.mesh = BoxMesh.new()
		seg.mesh.size = Vector3(12.0, 2.0, SEG_LEN)
		seg.position = Vector3(0.0, 0.0, float(i) * SEG_LEN)
		add_child(seg)
		track_segments.append(seg)

	# Player car setup
	car_body = RigidBody3D.new()
	car_body.mass = 1250.0
	car_body.name = "PlayerCar"
	car_body.position = Vector3(-4.0, 2.2, 8.0)
	car_body.rotation_degrees.y = 180.0
	add_child(car_body)

	car_mesh = MeshInstance3D.new()
	car_mesh.mesh = BoxMesh.new()
	car_mesh.mesh.size = Vector3(2.2, 1.0, 4.2)
	car_mesh.mesh.material = _make_material(Color(0.0, 0.96, 1.0)) # Neon cyan
	car_body.add_child(car_mesh)

	# Bot cars setup
	var bot_colors: Array[Color] = [
		Color(1.0, 0.15, 0.49), # pink
		Color(1.0, 0.85, 0.0),  # yellow
		Color(0.0, 1.0, 0.0)    # green
	]
	for n in range(NUM_BOTS):
		var bot := RigidBody3D.new()
		bot.mass = 1200.0
		bot.name = "Bot%d" % n
		bot.position = Vector3(float(n) * 4.0, 2.2, 3.0)
		bot.rotation_degrees.y = 180.0
		add_child(bot)
		bot_bodies.append(bot)

		var bot_mesh := MeshInstance3D.new()
		bot_mesh.mesh = BoxMesh.new()
		bot_mesh.mesh.size = Vector3(2.2, 1.0, 4.2)
		bot_mesh.mesh.material = _make_material(bot_colors[n])
		bot.add_child(bot_mesh)
		bot_meshes.append(bot_mesh)

	player_cam = get_viewport().get_camera_3d()
	show_countdown()

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy = 1.5
	return mat

func show_countdown() -> void:
	var label := Label3D.new()
	label.text = "3..2..1..GO!"
	label.position = Vector3(0.0, 12.1, 30.0)
	label.rotation_degrees.y = 180.0 
	add_child(label)
	await get_tree().create_timer(2.8).timeout
	label.queue_free()
	race_started = true

func _process(delta: float) -> void:
	if not race_started:
		return
	if finished:
		return

	# Input: WASD/arrow keys for player
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("w"):
		throttle = 1.0
	else:
		throttle = 0.0

	steering = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("a"):
		steering = -turn_rate
	elif Input.is_action_pressed("ui_right") or Input.is_action_pressed("d"):
		steering = turn_rate

	# Camera follows player
	if player_cam != null and car_body != null:
		var campos := car_body.global_transform.origin + Vector3(0.0, 15.0, -17.0)
		# Adjust camera offset based on new rotation (facing +Z, so back is -Z)
		# Actually, if we want camera behind, and car looks at +Z (local -Z), then 'behind' is local +Z.
		# Original code: global_transform.origin + Vector3(0, 15, -17)
		# If we rotate 180, we should probably check camera logic.
		# Let's rely on look_at.
		# But the offset Vector3(0, 15, -17) is in global space? No, it's added to origin.
		# If car is at 0,0,0 facing +Z. We want camera at 0,15,-17?
		# -17 Z is "behind" if forward is +Z? No, -Z is usually "forward" in Godot.
		# If car is rotated 180, "Forward" (local -Z) points to World +Z.
		# "Back" (local +Z) points to World -Z.
		# So -17 (World) is behind the car (which is moving to World +Z from 0).
		# Wait. 8.0 Start Z. Moving to 950.0 Z.
		# So "Behind" the car is smaller Z.
		# So Camera should be at Z < Car.Z.
		# -17 offset (fixed global) might be wrong if it's meant to be relative.
		# But here it is `car_body.global_transform.origin + Vector3(...)`.
		# So it adds -17 to Z.
		# If Car Z increases, Cam Z = Car Z - 17.
		# This places Camera at smaller Z (behind). CORRECT.
		
		player_cam.transform.origin = campos
		player_cam.look_at(car_body.global_transform.origin, Vector3.UP)

func _physics_process(delta: float) -> void:
	if not race_started or finished:
		return

	# Player car physics
	var fwd: Vector3 = car_body.transform.basis.z.normalized()
	if throttle > 0.0 and car_body.linear_velocity.length() < max_speed:
		car_body.apply_central_force(-fwd * accel * throttle)
	car_body.apply_torque(Vector3.UP * steering * car_body.linear_velocity.length() * 0.15)

	# Player finish check
	if car_body.global_transform.origin.z >= TRACK_LEN and not finished:
		var pos := car_body.global_transform
		pos.origin.z = TRACK_LEN
		car_body.global_transform = pos
		finished = true
		winner = "Player"
		_show_finish_label()

	# Bot AI and finish check
	for i in range(NUM_BOTS):
		var bot: RigidBody3D = bot_bodies[i]
		if bot.global_transform.origin.z < TRACK_LEN and not finished:
			var bot_fwd: Vector3 = bot.transform.basis.z.normalized()
			bot.apply_central_force(-bot_fwd * bot_speed[i])
		elif bot.global_transform.origin.z >= TRACK_LEN and not finished:
			var bpos := bot.global_transform
			bpos.origin.z = TRACK_LEN
			bot.global_transform = bpos
			finished = true
			winner = "Bot%d" % i
			_show_finish_label()

func _show_finish_label() -> void:
	var finish_label := Label3D.new()
	finish_label.text = "%s Finished!" % winner
	finish_label.position = Vector3(0.0, 12.1, car_body.global_transform.origin.z)
	finish_label.rotation_degrees.y = 180.0
	add_child(finish_label)
	await get_tree().create_timer(1.8).timeout
	finish_label.queue_free()
