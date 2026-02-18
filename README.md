# Aura Rush

**Aura Rush** is a high-speed, neon-styled 3D arcade racing game built with **Godot 4.6**. Race against 3 AI-controlled bots on a 3000m straight neon track, collect Aura orbs to charge your boost meter, and master the physics-based car controls to cross the finish line first.

## 🏁 Overview

In **Aura Rush**, speed and skill are everything. Compete in a straight-line sprint against 3 opponent bots on a luminous, barrier-lined track.

- **Race 3000m**: A single straight track divided into 4 lanes, bordered by neon barriers (cyan on the left, pink on the right).
- **Collect Aura Orbs**: Glowing cyan spheres scatter the track — collecting them fills your Aura meter and gives a small time bonus (-0.1s each).
- **Overtake for Bonuses**: Passing an opponent awards +10 Aura points instantly.
- **Stay Clean**: Collisions with bots cost -15 Aura and reset your streak multiplier.
- **Auto-Respawn**: Fall off the track? The game detects it and respawns you safely without losing progress.
- **Flip Recovery**: If your car stays flipped for over 1.5 seconds, it auto-corrects orientation.

## ✨ Features

### 🏎️ Vehicle Physics (VehicleBody3D)
- Full **VehicleBody3D**-based player car with 4 independent `VehicleWheel3D` nodes (front-steer, rear-traction).
- **75,000 N max engine force**, proper brake/reverse logic, and speed-dependent steering reduction at high speeds.
- **Speed-synced jump**: Jump force scales with current speed (capped at 12,000 N), with mid-air steering and auto-stabilization torque for clean landings.
- **Raycast ground detection** with fallback velocity check for reliable grounded state.
- **Side bumpers** with frictionless physics materials to prevent wall-sticking.
- **Input buffering**: Throttle presses during countdown are buffered and applied at race start for perfect launches.

### 🎨 Neon Visual Style
- **Custom Fresnel edge-glow shader** on all cars — dark metallic body with pulsating neon edge emission.
- **Procedural Pagani-inspired supercar models**: Built entirely in code using capsules, prisms, boxes, and cylinders — featuring a bubble cockpit, pointy nose, curvy fenders, quad exhaust pipes, and split rear wing.
- Player car is **neon cyan**; bots are **pink**, **yellow**, and **green**.
- Glowing barrier walls, lane dividers, and a massive red end wall.

### ⚡ Aura System
- **Aura Meter** (0–100): Fills by collecting orbs (+5 × streak multiplier), overtaking (+10), drifting (+2/s), and proximity driving (+1/s).
- **Aura Burst**: When full, activates a 45% speed boost for 3 seconds.
- **Penalties**: Collisions (-15 Aura, lose streak), off-track driving (-3/s drain).
- **Streak Multiplier**: Consecutive clean actions increase collection rate.

### 🤖 Bot AI
- 3 AI opponents with randomized speeds (40–52 m/s per session).
- Lane-change decision system with 1.5s cooldown and smooth interpolated lateral movement.
- Banking animation during lane changes for visual polish.
- All bots are locked during countdown and receive a randomized ±5% speed variation at launch.

### 🗺️ Dynamic HUD
- **Position indicator** (center-left) with green/red flash on rank changes.
- **Aura meter** (center-right) with elastic pulse animation on orb collection.
- **Race timer** (top-right) with best time persistence (saved to `user://save_data.cfg`).
- **Vertical minimap** (top-left) showing player (white) and bot (colored) positions relative to finish.
- **Countdown overlay** (3 → 2 → 1 → GO!) with yellow → green color transition and elastic scale animation.
- **Recover alert** banner when the car is auto-righted after flipping.
- **Results screen**: Dimmed overlay with animated panel showing winner, position, and best time.

### 🎮 Camera System
- Smooth **chase camera** that follows behind the car with configurable height (4m), distance (8m), and look-ahead (20m).
- **Mouse-look mode**: Toggle with `C` for free-look camera rotation (pitch-limited to -60° / +30°).
- Camera is detached as top-level and lerps to target to prevent white-flash at scene start.

### ⏸️ Pause Menu
- Resume, Settings (placeholder), Restart, and Quit buttons.
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

Developed by **Nikunj Raykundlia**.
Built with [Godot Engine](https://godotengine.org/)
