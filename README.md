# Aura Rush

**Aura Rush** is a high-speed, neon-styled arcade racing game built with **Godot 4**. Race against AI bots on a procedurally generated straight track, collect Aura Orbs to boost your speed, and master the art of risk-reward driving to claim victory.

## 🏁 Overview

In **Aura Rush**, you don't just drive—you build **Aura**. Collect energy orbs, drift cleanly, and perform daring overtakes to charge your Aura Meter. Unleash it for a massive speed burst to leave your opponents in the dust.

The race is a 2000m sprint to the finish line. Can you beat the bots and set a new personal best?

## ✨ Features

*   **Procedural Track Generation**: A 2000m infinite-style straight track with neon barriers and lane dividers.
*   **Aura System**:
    *   **Collect Orbs**: Grab blue Aura Orbs for points.
    *   **Risk & Reward**: Overtake opponents and drive dangerously to gain Aura.
    *   **Aura Burst**: Fill your meter to trigger a high-speed boost!
*   **AI Opponents**: Race against 3 competitive bots with unique behaviors and lane-changing logic.
*   **Physics-Based Arcade Controls**: partial physics simulation for realistic weight transfer mixed with arcade responsiveness.
*   **Dynamic HUD**: Real-time position tracking, speedometer, aura meter, and lap/distance timers.
*   **Neon Aesthetics**: smooth, glowing visuals for an immersive futuristic racing experience.

## 🎮 Controls

| Action | Keyboard | Controller |
| :--- | :--- | :--- |
| **Accelerate** | `W` or `Up Arrow` | `R2` / `RT` |
| **Brake / Reverse** | `S` or `Down Arrow` | `L2` / `LT` |
| **Steer** | `A` / `D` or `Left` / `Right` | Left Stick |
| **Jump** | `Space` | `A` / `Cross` |
| **Reset Car** | `R` | `Select` |
| **Toggle Camera** | `C` | `Y` / `Triangle` |
| **Pause** | `Esc` | `Start` |

## 🛠️ Installation & Setup

1.  **Download Godot 4**: Ensure you have Godot Engine 4.x installed (developed on 4.4+).
2.  **Clone the Repository**:
    ```bash
    git clone https://github.com/nikunjraykundlia/AuraRush.git
    ```
3.  **Import**: Open Godot, click **Import**, and select the `project.godot` file in the `AuraRush` folder.
4.  **Run**: Press **F5** to play the main scene.

## 📂 Project Structure

*   `scripts/main.gd`: Core game loop, race logic, track generation, and AI management.
*   `scripts/car_controller.gd`: Player vehicle physics and input handling.
*   `scenes/track.tscn`: Base track assets (mesh/collision setup).
*   `scenes/hud.tscn`: User interface implementation.

## 📜 Credits

Developed by **Nikunj Raykundlia**.
Built with [Godot Engine](https://godotengine.org/).
