# Aura Rush - Game Design Document

## Overview

**Title:** Aura Rush  
**Genre:** 3D Arcade Racing  
**Engine:** Godot 4.4.1  
**Style:** Retro-futuristic, Neon Glow, 3D  
**Theme:** High-energy adventure and rivalry  
**Setting:** Neon-lit future, Sky City  

## Core Gameplay Loop

1. Drive forward at increasing speed
2. Collect aura through skill and risky driving
3. Use boost strategically to overtake opponents
4. Avoid crashes to maintain aura streak
5. Compete for top race position

---

## Game Systems

### 1. Straight Track Racing System

**Track Type:** Continuous forward racing track (non-circular)

#### Track Structure
- **Primary Direction:** Forward-only progression
- **Track Length:** 2000 meters
- **Track Width:** 16 meters (4 lanes)
- **Features:**
  - Long high-speed straight sections
  - Lane dividers with neon markings
  - Neon barrier walls (cyan left, pink right)
  - Risk-reward aura orb placement

#### Movement Flow
- Constant forward momentum
- Lane-based overtakes
- Lateral steering within track bounds
- No circular laps - pure distance racing

---

### 2. Aura Points System

**Core Purpose:** Aura Points are the primary skill-based scoring and momentum mechanic that rewards clean, risky, and high-performance driving.

#### How Players Collect Aura

| Source | Description | Value |
|--------|-------------|-------|
| **Aura Orbs** | Glowing energy orbs placed along racing lines | +5 points |
| **Clean Drift** | Controlled drift without collision | +2 per second |
| **Overtake Bonus** | Successfully passing an opponent | +10 points |
| **Proximity Driving** | High speed near opponents without collision | +1 per second |

#### Aura Meter Mechanics
- **Meter Type:** Continuous charge (0-100)
- **Full Meter Effect:** "Aura Burst"
  - 45% speed boost
  - Duration: 3 seconds
  - Visual: Bright white glow + motion blur

#### Risk/Penalty System
| Event | Penalty |
|-------|---------|
| Collision with bot | -15 aura, lose streak multiplier, 30% speed loss |
| Off-track driving | -3 aura per second drain |
| Wall hit | Speed reduction |

#### Streak Multiplier
- Successful aura bursts increase streak multiplier by 0.1
- Collisions reset streak to 1.0x
- Higher streak = faster aura collection

---

### 3. Bot AI System

**Number of Opponents:** 3 bots

#### Bot Behavior
- **Start Sequence:** AI cars remain locked until "GO" signal
- **Movement:** Constant forward at varied speeds (48-52 m/s)
- **Lane Changes:** Random with 1.5s cooldown
- **Reaction Time:** 0.22 seconds

#### Bot Colors
1. Pink (#FF267D)
2. Yellow (#FFD900)
3. Green (#00FF66)

---

### 4. Countdown System

**Sequence:** 3 → 2 → 1 → GO!

- **Tick Interval:** 1.0 second
- **Player Input:** Disabled during countdown
- **Bot AI:** Locked until GO signal
- **Visual:** Large 3D label, yellow → green on GO

---

### 5. Camera System

**Type:** Top-down 3D perspective with chase behavior

#### Camera Parameters
| Parameter | Value |
|-----------|-------|
| Height | 18 meters |
| Distance | 12 meters behind |
| Look-ahead | 15 meters forward |
| Smooth Speed | 6.0 (lerp factor) |

#### Behavior
- Follows player with slight forward look-ahead
- Smooth interpolation for cinematic feel
- Maintains top-down angle for visibility

---

## Controls

### Keyboard
| Input | Action |
|-------|--------|
| W / ↑ | Accelerate |
| S / ↓ | Brake |
| A / ← | Steer Left |
| D / → | Steer Right |
| Space / Enter | Activate Aura Burst |
| Esc | Pause |

### Controller
| Input | Action |
|-------|--------|
| Right Trigger | Accelerate |
| Left Trigger | Brake |
| Left Stick | Steering |
| A Button | Aura Burst |
| Start | Pause |

---

## Player Car Physics

| Parameter | Value |
|-----------|-------|
| Max Speed | 55 m/s (~200 km/h) |
| Boosted Speed | ~80 m/s (with Aura Burst) |
| Acceleration | 35 m/s² |
| Steer Speed | 8 m/s lateral |
| Brake Force | 50 m/s² deceleration |

---

## Race Objectives

### Primary Goal
Travel maximum distance while overtaking opponents

### Secondary Goal
Collect aura to maintain boost advantage

### Competition Type
Player vs 3 Bot Cars

### Win Condition
First to reach track end (2000m) wins

---

## Visual Style

### Color Palette
- **Player Car:** Neon Cyan (#00F5FF)
- **Track Surface:** Dark Gray (#1F1F2E)
- **Lane Dividers:** White (60% opacity)
- **Left Barrier:** Cyan (#00F5FF)
- **Right Barrier:** Pink (#FF267D)
- **Aura Orbs:** Cyan with bloom (#00F5FF)

### Effects
- Neon emission on all cars
- Glow intensity increases with aura level
- Bright white burst effect on Aura Burst activation
- Bloom post-processing enabled

---

## File Structure

```
project/
├── scenes/
│   ├── main.tscn          # Main game scene
│   ├── car.tscn           # Player car prefab
│   ├── track.tscn         # Track segments
│   └── hud.tscn           # HUD overlay
├── scripts/
│   ├── main.gd            # Core game logic + race system
│   ├── car_controller.gd  # VehicleBody3D controller
│   ├── track.gd           # Checkpoint management
│   └── hud.gd             # HUD updates
└── src/
    └── main.gd            # Alternative race implementation
```

---

## Future Enhancements

### Planned Features
- [ ] Proper 3D car models
- [ ] Particle effects (boost trails, collision sparks)
- [ ] Sound effects and music
- [ ] Multiple track variations
- [ ] Difficulty levels for bots
- [ ] Leaderboard integration
- [ ] Power-ups beyond aura orbs
- [ ] Mobile touch controls

### Stretch Goals
- [ ] Multiplayer racing
- [ ] Ghost mode / time trials
- [ ] Car customization
- [ ] Progressive unlocks

---

## Technical Notes

- Built for Godot 4.4.1
- Web (HTML5) target platform
- 60 FPS target
- Physics-lite approach (manual movement, not full VehicleBody3D for main race mode)
- RigidBody3D used for collision detection only

---

*Last Updated: Current Session*
