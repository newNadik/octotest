Drop your music tracks in this folder (or keep them in `assets/sound/...` if you prefer).

Recommended naming (example):
- `menu.ogg` (main menu loop)
- `game_start.ogg` (plays when entering new game)
- `game_loop_01.ogg`, `game_loop_02.ogg`, ... (in-game loop playlist)
- `last_scene.ogg` (final scene track)

Recommended format:
- `.ogg` for background music (smaller size than `.wav`)
- 44.1kHz or 48kHz
- -1 dB peak max, integrated loudness around -16 to -14 LUFS

How to assign:
1. Open `Project > Project Settings > Autoload`.
2. Click `MusicManager` to inspect it.
3. Assign the exported track slots:
   - `menu_music`
   - `game_start_music`
   - `game_loop_music_tracks` (Array, add all loop tracks here)
   - `game_loop_music` (optional fallback if playlist is empty)
   - `last_scene_music`
   - Optional: `game_loop_shuffle = true` for random order

Runtime behavior:
- Main menu scene calls `MusicManager.play_menu()`.
- Main game scene on **New Game** calls `MusicManager.play_game_start()`.
- Main game scene on **Continue/Load** calls `MusicManager.play_game_loop()`.
- Manager auto-fades from `game_start_music` into loop playlist near the end.
- While in `GAME_LOOP`, when one loop track ends, next playlist track starts automatically.

For your final scene trigger:
- Call `MusicManager.play_last_scene()` when that scene starts.
