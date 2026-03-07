# 3. Context and Scope

## 3.1 Business Context

```
┌─────────────────────────────────────────────┐
│           Star Wars: Armada                 │
│           Digital Edition                   │
│                                             │
│  ┌───────────┐    ┌───────────────────┐     │
│  │  Player 1  │◄──►│   Game Engine     │     │
│  └───────────┘    │   (Godot 4.5)     │     │
│                   │                   │     │
│  ┌───────────┐    │  ┌─────────────┐  │     │
│  │  Player 2  │◄──►│  │ Rules Engine│  │     │
│  └───────────┘    │  └─────────────┘  │     │
│                   │                   │     │
│                   │  ┌─────────────┐  │     │
│                   │  │  Game Data   │  │     │
│                   │  │  (Resources) │  │     │
│                   │  └─────────────┘  │     │
│                   └───────────────────┘     │
└─────────────────────────────────────────────┘
```

### External Interfaces

| Partner | Description |
|---------|-------------|
| Player 1 | Human player interacting via mouse/keyboard |
| Player 2 | Human player (local) or AI opponent |
| Game Data Files | Ship, squadron, and upgrade definitions loaded from resource files |
| Save Files | Local game state persistence |

## 3.2 Technical Context

```
┌──────────────────────────────────────────┐
│              Godot Engine 4.5            │
│                                          │
│  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │ Rendering│  │  Physics  │  │  Audio │ │
│  │ (Forward+)│  │ (2D/3D)  │  │        │ │
│  └──────────┘  └──────────┘  └────────┘ │
│                                          │
│  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │   Input   │  │   Scene  │  │Network │ │
│  │  System   │  │   Tree   │  │(future)│ │
│  └──────────┘  └──────────┘  └────────┘ │
│                                          │
│  ┌──────────────────────────────────────┐ │
│  │          GDScript Runtime            │ │
│  └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
        │              │              │
   Desktop OS      File System    (Network)
   (macOS/Win/      (Save/Load)   (future
    Linux)                        multiplayer)
```

> **Note:** Detailed context diagrams will be created during the architecture phase.
