# Aura Rush

**Aura Rush** is a high-speed, neon-styled arcade racing game built with **Godot 4**. Race against competitive AI bots on a straight luminous track, master the drift mechanics, and use strategic jumping to claim victory.

## 🏁 Overview

In **Aura Rush**, speed is king. Compete in a dense 2000m sprint against opponent bots. 
- **Start Strong**: Time your launch perfectly with the countdown.
- **Avoid Hazards**: Don't fall off the track! If you do, the **Respawn System** will get you back in the action, but time is precious.
- **Physics Mastery**: Use the new **Speed-Dependent Jump** to clear obstacles or realign yourself, and bounce off walls strategically without getting stuck.

Can you beat the bots and set a new personal best?

## ✨ Features

*   **⚡ 2000m Neon Track**: A procedurally generated straight track with glowing barriers, lane dividers, and a massive safety wall at the end.
*   **🏎️ Advanced Car Physics**:
    *   **Anti-Stick Walls**: Custom physics materials and side bumpers ensure you bounce off walls smoothly instead of grinding to a halt.
    *   **Dynamic Jumping**: Jump force scales with your speed. Use mid-air control to stabilize and rotate your car for the perfect landing.
    *   **Smart Ground Detection**: Robust raycast-based ground checks for reliable controls.
*   **🤖 AI Opponents**: Race against 3 bots with unique colors and competitive behavior.
*   **🗺️ Minimap System**: Real-time HUD minimap tracks player (White) and bot positions relative to the finish line.
*   **🔁 Auto-Respawn**: Fall off the edge? The game instantly detects it and respawns you safely on the track to keep the race going.
*   **🏆 Victory Screen**: A polished, high-contrast results screen highlighting the winner and your final rank.
*   **📊 Dynamic HUD**: 
    *   Real-time speedometer & Aura meter.
    *   Race timer & Best time tracking.
    *   Countdown sequence with "GO" animation.

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

1.  **Download Godot 4.6**: This project is compatible with Godot 4.6+.
2.  **Clone the Repository**:
    ```bash
    git clone https://github.com/nikunjraykundlia/AuraRush.git
    ```
3.  **Import**: Open Godot, click **Import**, and select the `project.godot` file in the `AuraRush` folder.
4.  **Run**: Press **F5** to play the main race scene.

## 📂 Project Structure

*   `scripts/main.gd`: Core game loop, race states (Countdown, Racing, Finished), and respawn logic.
*   `scripts/car_controller.gd`: Vehicle physics, input handling, and air control logic.
*   `scripts/hud.gd`: UI management including Minimap and Results screen.
*   `scenes/car.tscn`: Player vehicle setup with side bumpers and physics materials.
*   `scenes/main.tscn`: Main entry point for the race level.

## 📜 Credits

Developed by **Nikunj Raykundlia**.
Built with [Godot Engine](https://godotengine.org/).
