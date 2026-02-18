# Arcade Racing Game - Godot 4.4 Template

A basic 3D arcade racing game template built with Godot 4.4, featuring placeholder assets using simple cubes and spheres.

## Features

- **VehicleBody3D-based car physics** with realistic wheel suspension
- **Complete input system** with keyboard and controller support
- **HUD elements**: speedometer, lap timer, checkpoint counter
- **Track system** with checkpoints and lap counting
- **Pause menu** with resume/settings/quit options
- **Dual camera modes**: 
  - Third-person follow camera (default)
  - Mouse-controlled free look camera
- **Jump mechanic** for arcade-style gameplay

## Project Structure

```
template/
├── project.godot           # Project configuration
├── scenes/
│   ├── main.tscn          # Main scene with environment
│   ├── car.tscn           # Car with VehicleBody3D
│   ├── track.tscn         # Track with barriers and checkpoints
│   └── hud.tscn           # HUD overlay
└── scripts/
    ├── main.gd            # Main game controller
    ├── car_controller.gd  # Car physics and input
    ├── track.gd           # Checkpoint management
    └── hud.gd             # HUD updates
```

## Controls

### Keyboard
- **W** - Accelerate forward / Brake while in reverse
- **S** - Brake / Reverse (hold after stopping to reverse)
- **A/D** - Steer left/right
- **Space** - Jump
- **C** - Toggle camera mode (Follow/Mouse Look)
- **Esc** - Pause
- **Mouse** - Camera look (in Mouse Look mode)

### Controller
- **Right Trigger** - Accelerate forward / Brake while in reverse
- **Left Trigger** - Brake / Reverse (hold after stopping)
- **Left Stick** - Steering
- **A Button** - Jump
- **Y Button** - Toggle camera mode
- **Start** - Pause

## How to Use

1. **Open in Godot 4.4**:
   - Launch Godot 4.4
   - Select "Import" and navigate to this folder
   - Open the project

2. **Run the Game**:
   - Press F5 or click the Play button
   - The game will start with the car on the track

3. **Gameplay**:
   - Drive through all checkpoints in order
   - Complete laps around the track
   - Your lap times are tracked
   - Best lap time is saved

## Customization Guide

### Modifying the Car
- Edit `scenes/car.tscn` to change the car's appearance
- Adjust physics parameters in `scripts/car_controller.gd`:
  - `MAX_ENGINE_FORCE` - Acceleration power
  - `MAX_BRAKE_FORCE` - Braking power
  - `MAX_STEER_ANGLE` - Turning radius
  - `JUMP_FORCE` - Jump height
  - `CAMERA_HEIGHT` - Camera height in follow mode
  - `CAMERA_DISTANCE` - Camera distance behind car
  - `CAMERA_FOLLOW_SPEED` - Camera smoothing speed

### Modifying the Track
- Edit `scenes/track.tscn` to change track layout
- Add more checkpoints or barriers
- Modify ground size and appearance

### Adjusting Game Settings
- Edit `project.godot` to change:
  - Window resolution
  - Input mappings
  - Physics settings
  - Rendering quality

## Technical Details

### Scene Hierarchy
```
Main
├── DirectionalLight3D
├── WorldEnvironment
├── Car (VehicleBody3D)
│   ├── MeshInstance3D (body)
│   ├── CollisionShape3D
│   ├── 4x VehicleWheel3D
│   └── CameraMount
│       └── Camera3D
├── Track
│   ├── Ground (StaticBody3D)
│   ├── Barriers
│   └── Checkpoints (Area3D nodes)
├── HUD (CanvasLayer)
│   ├── SpeedPanel
│   ├── LapPanel
│   └── CheckpointPanel
└── PauseMenu (CanvasLayer)
```

### Key Features Implementation

- **Car Physics**: Uses Godot's built-in VehicleBody3D for realistic car behavior
- **Checkpoint System**: Area3D nodes detect when the car passes through
- **Lap Counting**: Validates checkpoint order before counting a lap
- **Speed Calculation**: Converts linear velocity to km/h
- **Camera System**: Two modes available:
  - **Follow Mode** (default): Automatic third-person camera that follows behind the car
  - **Mouse Look Mode**: Manual camera control with mouse for custom viewing angles

## Best Practices Used

1. **GDScript 2.0 syntax** with type hints where appropriate
2. **Signal-based communication** between systems
3. **@onready variables** for node references
4. **Modular scene structure** for easy customization
5. **Clean separation of concerns** (physics, UI, game logic)

## Future Enhancements

Consider adding:
- Multiple car models
- Different track layouts
- Power-ups and boosts
- AI opponents
- Sound effects and music
- Particle effects
- Better visual assets
- Time trial modes
- Multiplayer support

## Requirements

- Godot Engine 4.4 or later
- OpenGL ES 3.0 / Vulkan compatible graphics

## License

This template is provided as-is for educational and development purposes.

# AuraRush
