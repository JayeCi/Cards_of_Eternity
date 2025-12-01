# 3D Map System - Cards of Eternity

## Overview
This is a complete 3D map system with grid-based movement, fog of war, branching paths, and visual effects. The player can navigate through various encounter nodes in a 3D space, with smooth camera transitions and interactive UI.

---

## 📁 File Structure

### Core Scripts
- **`map_scene_3d.gd`** - Main scene controller, manages the entire 3D map system
- **`map_node_3d.gd`** - Individual map node (encounter, shop, boss, etc.)
- **`map_player_3d.gd`** - Player character controller with grid-based movement
- **`map_camera_3d.gd`** - Camera controller with smooth focus transitions
- **`map_generator_3d.gd`** - Generates map nodes from configuration
- **`map_ui_overlay_3d.gd`** - UI overlay for node information and controls
- **`map_audio_3d.gd`** - Audio system for ambient sounds and SFX

### Scene Files
- **`3DMAPSCENE_NEW.tscn`** - Main 3D map scene (USE THIS ONE!)
- **`MapNode3D.tscn`** - Node template
- **`PortalHub3D.tscn`** - Portal hub model
- **`MapUIOverlay3D.tscn`** - UI overlay

---

## 🎮 Features

### ✅ Implemented Features

1. **Grid-Based Movement System**
   - Player moves from node to node on a grid
   - Smooth animation with arc movement
   - Idle bounce animation when stationary

2. **Fog of War**
   - Nodes are hidden until revealed
   - Connected nodes are revealed when player reaches a node
   - Visual difference between revealed and hidden nodes

3. **Portal Hub System**
   - Starting point that player can return to
   - Uses logic from earth_map_scene
   - Portal represented by 3D torus model with glow effect

4. **Branching Paths**
   - 22 nodes across 7 layers
   - Multiple routes from start to boss
   - Same configuration as 2D map system

5. **Node Types**
   - Fight encounters
   - Elite encounters
   - Boss battles
   - Shops
   - Rest sites
   - Elemental events (fire, water, wind, earth)
   - Exploration nodes
   - Portal hub

6. **Camera System**
   - Fixed camera above the map
   - Smooth focus on clicked nodes
   - Zoom in/out with mouse wheel
   - Return to overview with ESC key

7. **Visual Effects**
   - Color-coded nodes by type
   - Glow effects (OmniLight3D)
   - Particle systems for each node
   - Path lines showing connections
   - Hover effects (scale and glow changes)

8. **Sound System**
   - Ambient forest sounds
   - Background music
   - SFX for node clicks, hovers, movement
   - Separate audio buses (SFX, Music)

9. **UI Overlay**
   - Node information panel
   - Tooltips on hover
   - Return to hub button
   - Realm name display
   - Difficulty stars

---

## 🚀 How to Use

### Setting Up the Scene

1. **Replace the old 3DMAPSCENE.tscn**:
   ```
   Rename 3DMAPSCENE.tscn to 3DMAPSCENE_OLD.tscn (backup)
   Rename 3DMAPSCENE_NEW.tscn to 3DMAPSCENE.tscn
   ```

2. **The map will automatically generate when you run the scene!**
   - All nodes are created from `map_generator_3d.gd`
   - Player starts at Portal Hub
   - Camera focuses on starting position

### Controls

- **Left Click** - Click on a reachable node to move there
- **WASD** - Pan camera around the map
- **Mouse Wheel** - Zoom in/out
- **ESC** - Return camera to default view (also resets pan)
- **Hover** - Hover over nodes to see tooltips

### Customizing the Map

1. **Edit Node Configuration**:
   Open `map_generator_3d.gd` and modify the `node_config` dictionary:
   ```gdscript
   "Node_1A": {
	   "type": "fight",
	   "pos": Vector2(240, 550),  # 2D position (auto-converted to 3D)
	   "enemy": "Forest Guardian",
	   "deck": ["Dirt", "Fungoo"],
	   "difficulty": 1,
	   "description": "A small forest guardian blocks your path.",
	   "connections": ["Node_2A", "Node_2B"]
   }
   ```

2. **Add New Node Types**:
   - Add type to `map_node_3d.gd` node_colors dictionary
   - Add icon/texture if needed
   - Update particle effects in `setup_particles()`

3. **Customize Visuals**:
   - Edit `map_node_3d.gd` for node appearance
   - Modify particle effects in `setup_particles()`
   - Change colors in `node_colors` dictionary

4. **Adjust Camera**:
   - Modify `map_camera_3d.gd` exported variables:
	 - `default_distance` - Height above map
	 - `default_angle` - Viewing angle
	 - `move_speed` - Camera transition speed

5. **Change Grid Spacing**:
   - In `map_scene_3d.gd`, change `grid_cell_size` export variable

---

## 🎨 Visual Customization

### Node Colors
Edit `map_node_3d.gd` line 49-60:
```gdscript
var node_colors := {
	"fight": Color(0.8, 0.3, 0.3, 1),    # Red
	"elite": Color(0.6, 0.3, 0.8, 1),    # Purple
	"boss": Color(0.9, 0.2, 0.2, 1),     # Deep Red
	"shop": Color(0.9, 0.8, 0.3, 1),     # Gold
	# ... add more
}
```

### Particle Effects
Each node type can have unique particles. Edit `setup_particles()` in `map_node_3d.gd`.

### Player Model
Replace the default capsule with actual leader models:
- Edit `setup_player_model()` in `map_player_3d.gd`
- Call `set_leader_model(leader_card)` to load leader's 3D model

---

## 🔊 Adding Custom Sounds

1. **Load sound files** in `map_audio_3d.gd`:
```gdscript
func load_sound_effects():
    sounds["node_click"] = load("res://Audio/Sound FX/click.wav")
    sounds["node_hover"] = load("res://Audio/Sound FX/hover.wav")
    # etc...
```

2. **Call from map scene**:
```gdscript
map_audio.play_node_click()
map_audio.play_player_move()
```

---

## 🎯 Node Event System

When a player arrives at a node, `handle_node_event()` is called. Currently prints debug messages, but you can connect to your battle/shop systems:

```gdscript
func handle_node_event(node: MapNode3D):
    match node.encounter_type:
        "fight", "elite", "boss":
            # Transition to battle scene
            GameSession.start_battle(node.enemy_deck, node.enemy_leader)

        "shop":
            # Open shop UI
            ShopSystem.open_shop()

        "rest":
            # Show rest menu
            RestSystem.show_rest_menu()
```

---

## 🐛 Troubleshooting

### Map doesn't generate
- Check console for error messages
- Ensure `MapGenerator3D` node exists in scene tree
- Verify `map_generator_3d.gd` is attached to the node

### Nodes not clickable
- Ensure `input_ray_pickable = true` in `map_node_3d.gd`
- Check that Camera3D is set as current camera
- Verify collision shapes exist on nodes

### Camera not moving
- Check that `MapCamera3D` script is attached
- Ensure camera is not locked in editor
- Verify `move_speed` is > 0

### No sound
- Check that audio files exist in Audio folder
- Verify audio bus names ("SFX", "Music") match project settings
- Ensure `MapAudio3D` node exists

### Player not moving
- Check that nodes are marked as `is_reachable`
- Verify connections exist between nodes
- Check console for movement errors

---

## 🔮 Future Enhancements

Ideas for extending the system:

1. **Custom 3D Models for Each Node Type**
   - Replace sphere meshes with themed models
   - Animate models (idle, hover, revealed)

2. **Enhanced Particle Effects**
   - Different particle types per node
   - Trail effects for path lines
   - Explosion on node completion

3. **Dynamic Map Generation**
   - Procedurally generate node positions
   - Random branching paths each playthrough
   - Different layouts per realm

4. **Mini-map**
   - Show overview in corner of screen
   - Highlight current position
   - Toggle visibility

5. **Save/Load System**
   - Save node completion state
   - Remember player position
   - Track visited nodes

6. **Path Highlighting**
   - Show available paths from current node
   - Highlight optimal route
   - Show previously traveled paths

7. **Environmental Effects**
   - Weather based on realm (rain, snow, etc.)
   - Time of day system
   - Ambient creatures/NPCs

8. **Terrain Integration**
   - Place nodes on actual terrain height
   - Follow terrain contours with paths
   - Add terrain decorations around nodes

---

## 📝 Integration with Existing Systems

### Connecting to Battle System
```gdscript
# In map_scene_3d.gd, handle_node_event():
"fight":
	await TransitionFade.fade_out()
	GameSession.start_battle(node.enemy_deck, node.enemy_leader)
	get_tree().change_scene_to_file("res://Arena/battle_scene.tscn")
```

### Connecting to Portal Hub
```gdscript
# In map_scene_3d.gd, _on_return_to_hub():
await TransitionFade.fade_out()
get_tree().change_scene_to_file("res://EarthPortalScene.tscn")
```

### Connecting to Shop System
```gdscript
# In map_scene_3d.gd, handle_node_event():
"shop":
	var shop_panel = preload("res://World/MAP/shop_panel.tscn").instantiate()
	add_child(shop_panel)
	shop_panel.setup_shop(node)
```

---

## 🎓 Code Architecture

### Class Hierarchy
```
MapScene3D (Node3D)
├── MapCamera3D (Camera3D)
├── MapPlayer3D (Node3D)
├── NodeContainer (Node3D)
│   └── MapNode3D (Area3D) [x22]
├── PathLines (Node3D)
│   └── MeshInstance3D [lines]
├── MapAudio3D (Node)
├── MapGenerator3D (Node)
└── MapUIOverlay3D (CanvasLayer)
```

### Signal Flow
```
MapNode3D.clicked
  → MapScene3D._on_node_clicked
	→ MapCamera3D.focus_on_node
	→ MapPlayer3D.move_to_node

MapPlayer3D.movement_completed
  → MapScene3D._on_player_movement_completed
	→ MapScene3D.draw_all_path_lines
	→ MapScene3D.handle_node_event
```

---

## ✨ Credits

Built for **Cards of Eternity** using Godot 4.x with Terrain3D addon.

Inspired by map systems from:
- Slay the Spire
- Monster Train
- Griftlands

---

## 📄 License

Part of Cards of Eternity project.
