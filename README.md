<h1 align="center">Map Ambience</h1>

<p align="center">
  <a href="https://www.youtube.com/watch?v=u3LJnpc9kiE"><img src="https://img.youtube.com/vi/u3LJnpc9kiE/maxresdefault.jpg" alt="Watch on YouTube" width="600"></a>
</p>

## 📝 Description
This plugin lets you place ambience sound emitters anywhere in a map during gameplay.
Each emitter plays a configured sound or a random sound from a list, with configurable volume, attenuation, pitch, delay and duration.
Custom setups are saved per map and automatically loaded on every map start.
- Place and remove ambience emitters during gameplay via an in-game menu
- Each ambience type can define a single sound or a pool of sounds picked at random
- Configurable per emitter: spawn chance, sound duration, delay before playing, volume, attenuation and pitch
- Optional model attachment per emitter with a flag-controlled duration mode
- Ghost preview tracking for natural placement against grounds and walls
- [color=red]Requires AMX Mod X 1.9.0+[/color]

## 💬 Commands
- `say /ma` - Opens the Map Ambience menu.
- `say_team /ma` - Opens the Map Ambience menu.
- `say /mapambience` - Opens the Map Ambience menu.
- `say_team /mapambience` - Opens the Map Ambience menu.
- `ma_reload` - Reloads the configuration file.
- `mapambience_reload` - Reloads the configuration file.

## ⚙️ Configuration
```ini
# To add a new ambience track, follow the example below
# [Ambience Name]
# AMBIENCE_MODEL                  = Path of ambience's model
# AMBIENCE_FLAGS                  = a - Model           b - Duration
# AMBIENCE_SPAWN_CHANCE           = Ambience's respawn probability (0.0 = never, 1.0 = always)
# AMBIENCE_SOUND                  = Path to the sound file for the ambience
# AMBIENCE_SOUND_DURATION         = Minimum - Maximum duration time for the ambience's sound
# AMBIENCE_SOUND_DELAY            = Minimum - Maximum delay time before the ambience's sound plays
# AMBIENCE_SOUND_VOL              = Volume of the ambience's sound
# AMBIENCE_SOUND_ATTN             = Attenuation of the ambience's sound
# AMBIENCE_SOUND_PITCH            = Pitch of the ambience's sound
```

## 🔄 Changelog
```text
* v1.0: Initial release.
```
