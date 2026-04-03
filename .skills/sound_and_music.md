# Sound & Music Implementation Guide

> Skill file for consistent audio implementation across the project.

## Architecture

| Component       | Type     | Responsibility                          |
|----------------|----------|-----------------------------------------|
| `SfxManager`   | Autoload | One-shot & rhythmic SFX playback        |
| `MusicManager` | Autoload | Background music with crossfade         |
| `sound_config.json` | Data | All volumes, paths, rhythms, durations |

**Rule:** Never create raw `AudioStreamPlayer` nodes in scenes. Always use
`SfxManager` or `MusicManager`.

## Configuration: `Resources/Sound/sound_config.json`

```json
{
  "sfx": {
    "<key>": { "path": "res://Resources/Sound/fx/<file>", "volume": 1.0 }
  },
  "sfx_rhythms": {
    "<name>": [300, 100, 300]            // pause durations (ms) between shots
  },
  "music": {
    "<key>": { "path": "res://Resources/Sound/music/<file>", "volume": 1.0 }
  },
  "music_fade_duration_s": 3.0,
  "destruction_override_duration_s": 60.0
}
```

- **Volumes** are linear (0.0 – 1.0). Converted to dB internally.
- **Rhythms** define pause durations between consecutive shots; the first
  shot is always immediate, so an array of N pauses produces N+1 shots.

## Adding a New SFX

1. Place the audio file in `Resources/Sound/fx/`.
2. Add a JSON entry to `sound_config.json → sfx`:
   ```json
   "my_new_sound": { "path": "res://Resources/Sound/fx/my_new_sound.wav", "volume": 0.8 }
   ```
3. Call `SfxManager.play_sfx("my_new_sound")` from any script.
4. For rhythmic playback, also add a rhythm array under `sfx_rhythms`.

## Adding a New Music Track

1. Place the audio file in `Resources/Sound/music/`.
2. Add a JSON entry to `sound_config.json → music`.
3. Call `MusicManager.play("my_new_track")`.

## SFX Categories for Button Handlers

| Action                      | SFX key             |
|-----------------------------|---------------------|
| Confirm / Accept / Select   | `droid_sound`       |
| Skip / Dismiss / Cancel / Close | `skip_beep`    |
| Ship movement confirm       | `star_destroyer_flyby` |
| Dice roll (capital ship)    | `turbolasers`       |
| Dice roll (Rebel squadron)  | rhythmic `x_wing_shooting` |
| Dice roll (Imperial squadron) | rhythmic `tie_shooting` |
| Squadron move (Rebel)       | `x_wing_flyby`      |
| Squadron move (Imperial)    | `tie_flyby`          |

## Music Track Selection Logic

### Main Menu
- `rebel_theme` plays on load.

### Gameplay (shuffled playlist)
- 12 tracks (`in_game_1` … `in_game_12`) are shuffled at game start.
- Each track plays once (no loop), then crossfades to the next.
- After all 12 have played, the list is reshuffled and playback continues.
- Track count is configurable via `in_game_track_count` in `sound_config.json`.

### Destruction Override
- Rebel ship destroyed → `imperial_march` for 60 s, then resume playlist.
- Imperial ship destroyed → `rebel_theme` for 60 s, then resume playlist.
- Duration configurable via `destruction_override_duration_s`.

### Victory
- Imperial wins → `imperial_march`
- Rebel wins → `rebel_theme`

## Crossfade Pattern

`MusicManager` maintains two `AudioStreamPlayer` nodes (A/B). When switching
tracks, the incoming player starts at full volume while the outgoing player
fades to silence over `music_fade_duration_s` seconds via a Tween. This
avoids silence gaps.

## Checklist for Sound Changes

- [ ] Audio file placed in correct directory (`fx/` or `music/`)
- [ ] Entry added to `sound_config.json` with path and volume
- [ ] Volume tuned (play-test — 1.0 may be too loud for some clips)
- [ ] SfxManager/MusicManager call added in the correct handler
- [ ] No raw `AudioStreamPlayer` nodes created in scene scripts
- [ ] Godot re-imported the audio file (check `.import` file exists)
