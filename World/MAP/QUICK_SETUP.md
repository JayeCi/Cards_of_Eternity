# Quick Setup Guide - 3D Map System

## 🚀 Getting Started in 3 Steps

### Step 1: Replace the Scene File
1. In Godot, navigate to `World/MAP/`
2. Rename `3DMAPSCENE.tscn` → `3DMAPSCENE_OLD.tscn` (backup)
3. Rename `3DMAPSCENE_NEW.tscn` → `3DMAPSCENE.tscn`

### Step 2: Open and Run
1. Double-click `3DMAPSCENE.tscn` to open it
2. Press F6 (or click Run Current Scene)
3. The map should automatically generate!

### Step 3: Test the Features
- **Click** on glowing nodes to move the player
- **Mouse Wheel** to zoom in/out
- **Hover** over nodes to see tooltips
- **ESC** to reset camera view

---

## ✅ What You Should See

When the scene loads, you should see:

1. **Camera View** - Looking down at the terrain from above
2. **Portal Hub** - Purple glowing torus ring at the starting position
3. **Player** - Blue capsule hovering at the Portal Hub
4. **Connected Nodes** - 3 colored spheres connected to the hub (revealed)
5. **Hidden Nodes** - Dark gray semi-transparent spheres (fog of war)
6. **UI Overlay** - Top bar with "Return to Hub" and "Earth Realm"
7. **Path Lines** - Semi-transparent lines connecting revealed nodes

---

## 🎮 Testing the System

### Test Movement
1. Click on one of the 3 revealed nodes connected to Portal Hub
2. Player should smoothly move to that node with an arc animation
3. New nodes should be revealed (fog of war removed)
4. Path lines should update

### Test Camera
1. Use **WASD** to pan the camera around the map
2. Click on a distant node - camera should smoothly focus on that node
3. Scroll mouse wheel to zoom in/out
4. Press ESC to return to overview (also resets pan)

### Test UI
1. Hover over a revealed node → tooltip appears
2. Click a node → info panel appears at bottom
3. Info shows: node name, type, difficulty, description

---

## 🐛 Troubleshooting

### "No nodes appear!"
- Check console (Output tab) for errors
- Ensure all script files are in `World/MAP/`
- Verify MapGenerator3D exists in scene tree

### "Player doesn't move!"
- Click only on **revealed** (colored) nodes
- Click on nodes **connected** to your current node
- Check that the node glows when you hover (means it's clickable)

### "Camera stuck!"
- Press ESC to return to default view
- Check that Camera3D script is attached
- Verify camera is not locked in editor

### "No sound!"
- Check that audio files exist in `Audio/Sound FX/Realms/Earth/`
- Verify audio bus setup (SFX, Music buses should exist)
- Check volume sliders in audio settings

---

## 🎨 Quick Customization

### Change Starting Position
In `map_generator_3d.gd`, edit the PortalHub position:
```gdscript
"PortalHub": {
    "pos": Vector2(343, 472),  # Change these numbers
    ...
}
```

### Change Grid Spacing
In the scene inspector, select `MapScene3D` node:
- Find "Grid Cell Size" property
- Change from 2.0 to desired value (larger = more spread out)

### Toggle Fog of War
In the scene inspector, select `MapScene3D` node:
- Find "Enable Fog of War" property
- Uncheck to reveal all nodes at start

### Toggle Path Lines
In the scene inspector, select `MapScene3D` node:
- Find "Show Path Lines" property
- Uncheck to hide connection lines

---

## 📊 Expected Console Output

When you run the scene, you should see:
```
🗺️ Setting up 3D Map Scene...
🗺️ Generating 3D map from config...
  ✓ Created: PortalHub (hub) at (343, 472)
  ✓ Created: Node_1A (fight) at (240, 550)
  ✓ Created: Node_1B (fight) at (350, 550)
  ... (more nodes)
🔗 Setting up connections...
  ✓ PortalHub → ["Node_1A", "Node_1B", "Node_1C"]
  ... (more connections)
✅ 3D Map generation complete! Created 22 nodes
✅ 3D Map scene ready!
```

When you click a node:
```
Node clicked: Node_1A
Player moving from PortalHub to Node_1A
Player arrived at Node_1A
```

---

## 🎯 Next Steps

Once the basic system is working:

1. **Replace Player Model**
   - Edit `map_player_3d.gd` → `setup_player_model()`
   - Load actual leader 3D model instead of capsule

2. **Add Custom Node Models**
   - Edit `map_node_3d.gd` → `setup_visuals()`
   - Replace sphere meshes with themed 3D models

3. **Connect to Battle System**
   - Edit `map_scene_3d.gd` → `handle_node_event()`
   - Add transition to battle scene

4. **Connect to Portal Hub**
   - Edit `map_scene_3d.gd` → `_on_return_to_hub()`
   - Add transition back to EarthPortalScene

5. **Add Sound Effects**
   - Edit `map_audio_3d.gd` → `load_sound_effects()`
   - Load actual sound files

---

## 📞 Need Help?

Check the full documentation in `3D_MAP_SYSTEM_README.md` for:
- Complete feature list
- Architecture details
- Customization guide
- Code examples
- Integration instructions

---

## 🎉 Have Fun!

The 3D map system is now ready to use. Enjoy exploring and customizing it!
