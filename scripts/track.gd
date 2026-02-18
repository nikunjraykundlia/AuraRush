extends Node3D

@onready var checkpoints = $Checkpoints
var car: VehicleBody3D

func _ready():
	# Get reference to the car
	car = get_node("../Car")
	
	# Connect all checkpoint areas to the car
	if car:
		setup_checkpoints()

func setup_checkpoints():
	var checkpoint_areas = checkpoints.get_children()
	
	for i in range(checkpoint_areas.size()):
		var area = checkpoint_areas[i]
		if area is Area3D:
			# Connect the body_entered signal
			area.body_entered.connect(_on_checkpoint_body_entered.bind(i))

func _on_checkpoint_body_entered(body: Node3D, checkpoint_index: int):
	# Check if the body that entered is our car
	if body == car:
		# Notify the car that it entered a checkpoint
		if car.has_method("on_checkpoint_entered"):
			car.on_checkpoint_entered(checkpoint_index)
			
		# Visual feedback for checkpoint
		show_checkpoint_feedback(checkpoint_index)

func show_checkpoint_feedback(checkpoint_index: int):
	# Flash the checkpoint briefly
	var checkpoint_areas = checkpoints.get_children()
	if checkpoint_index < checkpoint_areas.size():
		var checkpoint = checkpoint_areas[checkpoint_index]
		var mesh = checkpoint.get_node("MeshInstance3D")
		if mesh:
			# Create a simple flash effect
			var original_color = mesh.material_override.albedo_color
			mesh.material_override.albedo_color = Color(0, 1, 0, 1)  # Green flash
			
			# Reset after a short delay
			await get_tree().create_timer(0.3).timeout
			mesh.material_override.albedo_color = original_color
