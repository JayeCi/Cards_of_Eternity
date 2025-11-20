# Quick Start Guide - Map Generator

## Step 1: Attach the Script

1. Open `earth_map_screen.tscn` in Godot Editor
2. Select the **root node** named `EarthMapScene` (the very top node in the Scene tree)
3. In the Inspector, click the scroll icon next to "Script" → "Attach Script"
4. Choose `map_generator.gd` from `World/MAP/` folder
5. Click "Open"

## Step 2: Save and Watch the Console

1. Press `Ctrl+S` (or Cmd+S on Mac) to save the scene
2. **Open the Output console** at the bottom of Godot (next to Debugger tab)
3. You should see output like:

```
🗺️ Map Generator: Script loaded
✅ Found NodeLayer at: EarthMapScene/MapRoot/NodeLayer
🗺️ Starting map generation...
🧹 Clearing X old nodes...
✅ Cleared X old nodes
📋 Generating 22 nodes...
  ✓ Found existing PortalHub
  ✓ Created: Node_1A (fight) at (240, 550)
  ✓ Created: Node_1B (fight) at (350, 550)
  ... (continues for all 22 nodes)
🔗 Setting up connections...
  ✓ PortalHub → [Node_1A, Node_1B, Node_1C]
  ... (continues)
✅ Map generation complete! Created 22 nodes
🎉 Map generation complete! Check the NodeLayer in the scene tree.
```

## Step 3: Verify Nodes Were Created

1. In the Scene tree on the left, expand:
   - `EarthMapScene`
   - `MapRoot`
   - `NodeLayer`

2. You should now see **22 nodes** under NodeLayer:
   - PortalHub
   - Player
   - Node_1A, Node_1B, Node_1C
   - Node_2A, Node_2B, Node_2C, Node_2D
   - Node_3A, Node_3B, Node_3C
   - Node_4A, Node_4B, Node_4C
   - Node_5A, Node_5B
   - Node_6A, Node_6B, Node_6C
   - Node_BOSS

## Step 4: Clean Up

1. Select the `EarthMapScene` root node again
2. In the Inspector, click the scroll icon next to "Script"
3. Choose "Clear" to remove the map_generator script
4. Press `Ctrl+S` to save

**The nodes are now permanently part of your scene!**

---

## Troubleshooting

### ❌ "Could not find MapRoot/NodeLayer"

**Problem**: The script can't find the NodeLayer node

**Solution**:
- Make sure the script is attached to the **root** `EarthMapScene` node, NOT a child node
- Verify that your scene has the structure: `EarthMapScene/MapRoot/NodeLayer`
- If NodeLayer has a different path, update the script on line 15

### ❌ Nothing appears in the console

**Problem**: The @tool script isn't running

**Solutions**:
1. Make sure `@tool` is on line 3 of map_generator.gd
2. Try closing and reopening the scene
3. Restart Godot Editor
4. Check "Editor" settings → "Text Editor" → make sure auto-reload is enabled

### ❌ "Failed to instantiate MapNode"

**Problem**: Can't load the MapNode scene

**Solution**:
- Verify that `res://World/MAP/map_node.tscn` exists
- Open map_node.tscn to make sure it's not broken
- Try reloading the project (Project → Reload Current Project)

### ❌ Nodes appear but have no textures

**Problem**: Node textures aren't loading

**Solution**:
- This is normal! Textures are set in the MapNode's `_ready()` function
- Run the game to see the proper textures
- Or select a node and check "Texture Normal" in Inspector

### ⚠️ Nodes appear in weird positions

**Problem**: Map is too large or small for viewport

**Solution**:
1. Select `MapCamera` node
2. Update camera limits in Inspector:
   ```
   Limit Bottom: 1300 (instead of 830)
   ```
3. Adjust `min_zoom` and `max_zoom` if needed

---

## Next Steps

After nodes are generated:

1. **Adjust Camera** - Update MapCamera limits to Y: 1300
2. **Extend Background** - Make sure map background covers all nodes
3. **Test the Map** - Run the game and try different paths
4. **Balance Difficulty** - Adjust enemy decks in individual nodes
5. **Add Custom Art** - Set custom textures for specific nodes

---

## Manual Alternative

If the script still doesn't work, you can create nodes manually:

1. Right-click `NodeLayer` → Instance Child Scene
2. Select `map_node.tscn`
3. Set the node properties in Inspector:
   - Position (offset_left, offset_top)
   - encounter_type
   - enemy_name
   - enemy_deck (add CardData resources)
   - connected_nodes (drag other nodes into array)
   - difficulty

Repeat for all 22 nodes following the MAP_DESIGN.md layout.

---

Need help? Check MAP_DESIGN.md for the complete map layout and SETUP_INSTRUCTIONS.md for detailed information.
