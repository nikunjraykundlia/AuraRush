# Aura Rush

**Aura Rush** is a high-speed, neon-styled 3D arcade racing game built with **Godot 4.6**. Race against 7 AI-controlled bots on a 3000m straight neon track, collect Aura orbs to charge your unlimited boost meter, and master the physics-based car controls to cross the finish line first.

Play Online: [aurarush.vercel.app](https://aurarush.vercel.app)

## 🏁 Overview

In **Aura Rush**, speed and skill are everything. Compete in a straight-line sprint against 7 opponent bots on a luminous, barrier-lined track.

- **Race 3000m**: A single straight, widened track divided into 4 lanes for better overtaking, bordered by neon barriers with solid boundary walls.
- **Collect Aura Orbs**: Glowing cyan spheres scatter the track — collecting them instantly reduces race time (-0.1s) and applies a forward speed boost that scales seamlessly with your total Aura.
- **Overtake for Bonuses**: Passing an opponent awards +10 Aura points instantly.
- **Stay Clean**: Collisions with bots cost -15 Aura and reset your streak multiplier.
- **Auto-Respawn**: Fall off the track? The game detects it and respawns you safely without losing progress.
- **Flip Recovery**: If your car stays flipped for over 1.5 seconds, it auto-corrects orientation, stabilizing with all four wheels down.

## ✨ Features

### 🏎️ Vehicle Physics (VehicleBody3D)
- Full **VehicleBody3D**-based player car with 4 independent `VehicleWheel3D` nodes (front-steer, rear-traction).
- **Responsive Controls**: Proper acceleration, gradually synced braking/reverse logic, and snappy interpolation-based steering.
- **Targeted Jumps & Stabilization**: Jump height perfectly tuned to quickly clear opponent cars. Features mid-air steering, limited double jumps, and auto-stabilization torque for clean four-wheel landings.
- **Raycast ground detection** with fallback velocity check for reliable grounded state.
- **Side bumpers** with frictionless physics materials to prevent wall-sticking.
- **Input buffering**: Throttle presses during countdown are buffered and applied at race start for perfect launches without lag.

### 🎨 Neon Visual Style
- **Custom Fresnel edge-glow shader** on all cars — dark metallic body with pulsating neon edge emission.
- **Futuristic Supercar Models**: 3D vehicle models styled with a Pagani aesthetic, prominently featuring visible wheels and properly glowing edges.
- Player car is **neon cyan**; bot cars come in a full spectrum of colors (Pink, Yellow, Green, Purple, Orange, Blue, Red).
- Glowing barrier walls, lane dividers, and a massive neon finish line arching over the track.

### ⚡ Aura System
- **Infinite Aura Meter**: Fills by collecting orbs (+5 × streak multiplier), overtaking (+10), drifting (+2/s), and proximity driving (+1/s). There is no max cap.
- **Scaling Aura Boost**: Collecting orbs activates an instant 2-second forward thrust. The magnitude of this thrust scales aggressively as your overall Aura grows!
- **Penalties**: Collisions (-15 Aura, lose streak), off-track driving (-3/s drain).
- **Streak Multiplier**: Consecutive clean actions increase collection rate.

### 🤖 Bot AI
- **7 AI opponents** (Bot 1 through Bot 7) with randomized speeds (40–62 m/s per session).
- Lane-change decision system with 1.5s cooldown and smooth interpolated lateral movement.
- Banking animation during lane changes for visual polish.
- All bots are locked during countdown and receive a randomized ±5% speed variation at launch.

### 🗺️ Dynamic HUD
- **Real-time Minimap** (top-left) showing player and 7 bot positions relative to the finish line.
- **Dynamic Speed UI**: Toggleable speed display using `H`.
- **Position Indicator** (center-left) with green/red flash on rank changes.
- **Aura Meter** (center-right) showing total aura and elastic pulse animation on orb collection.
- **Race Timer** (top-right) with best time persistence (saved to `user://save_data.cfg`).
- **Countdown Overlay** (3 → 2 → 1 → GO!) with yellow → green color transition and elastic scale animation.
- **Results Screen**: Dimmed overlay showing the Winner Name, Player Position, Max Aura recorded, and Best Time.

### 🎮 Camera System
- Smooth **chase camera** that follows behind the car.
- **Driver Seat / Chase Toggle**: Switch between an immersive driver POV and follow camera using `C`.
- Camera is detached as top-level and lerps to target to prevent white-flash at scene start.

### ⏸️ Pause Menu
- Resume, Restart (`R`), Settings, and Quit buttons.
- Processes during `PROCESS_MODE_WHEN_PAUSED` so it remains responsive while the game is frozen.
- Mouse captured/released automatically on pause/resume.

## 🎮 Controls

| Action | Keyboard | Controller |
|:---|:---|:---|
| **Accelerate** | `W` | `R2 / RT` |
| **Brake / Reverse** | `S` | `L2 / LT` |
| **Steer Left** | `A` | Left Stick ← |
| **Steer Right** | `D` | Left Stick → |
| **Jump** | `Space` | `A / Cross` |
| **Toggle Camera** | `C` | `Y / Triangle` |
| **Toggle Speed HUD** | `H` | |
| **Restart Race** | `R` | |
| **Pause** | `Esc` | `Start` |

## 🛠️ Installation & Setup

1. **Download Godot 4.6+**: [godotengine.org/download](https://godotengine.org/download)
2. **Clone the Repository**:
    ```bash
    git clone https://github.com/nikunjraykundlia/AuraRush.git
    ```
3. **Import**: Open Godot → **Import** → select `project.godot` in the `AuraRush` folder.
4. **Install Web Export Templates** (if deploying): Editor → Manage Export Templates → Download and Install.
5. **Run**: Press **F5** to play the main race scene.

## 📜 Credits

Developed by **Nikunj Raykundlia**
Built with [Godot Engine](https://godotengine.org/)
