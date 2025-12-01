# How to Generate Map Nodes in Editor

The map nodes are now **pre-generated in the editor** so you can manually edit them, move them, change their properties, etc.

## 🔧 Generate Nodes (One-Time Setup)

### Step 1: Open the Scene
1. Open `World/MAP/3DMAPSCENE.tscn` in Godot

### Step 2: Run the Generator Script
1. In Godot, go to **Script** editor (or press F3)
2. Open `World/MAP/generate_nodes_editor.gd`
3. Click **File** → **Run** (or press Ctrl+Shift+X)

### Step 3: Save the Scene
1. You should see in Output:
   ```
   ✅ DONE! Created 22 nodes
   💾 Now SAVE THE SCENE (Ctrl+S) to persist the nodes!
   ```
2. Press **Ctrl+S** to save the scene
3. The nodes are now permanently in your scene!

## ✅ What You Get

After running the script and saving, you'll see in the **Scene Tree**:
```
MapScene3D
  └── NodeContainer
      ├── PortalHub (MapNode3D)
      ├── Node_1A (MapNode3D)
      ├── Node_1B (MapNode3D)
      ├── Node_1C (MapNode3D)
      ├── ... (22 nodes total)
```

## ✏️ Editing Nodes

Now you can **manually edit** any node in the Inspector:

### Select a Node
1. Click on any node in Scene Tree (e.g., `Node_1A`)
2. Look at the Inspector panel

### Edit Properties
You can change:
- **Encounter Type** - fight, elite, boss, shop, rest, etc.
- **Enemy Name** - "Forest Guardian", etc.
- **Description** - The text shown to player
- **Difficulty** - 1-5 stars
- **Position** - Move the node in 3D space
- **Connected Nodes** - Which nodes connect to this one
- **Is Revealed** - Start revealed or hidden (fog of war)
- **Grid Position** - X/Z coordinates

### Move Nodes Visually
1. Select a node in Scene Tree
2. Use the **3D transform gizmo** to drag it around
3. The position updates automatically

## 🎨 Adding New Nodes

### Method 1: Duplicate Existing Node
1. Right-click a node in Scene Tree
2. Click **Duplicate**
3. Rename it (e.g., "Node_Custom_1")
4. Edit its properties
5. Add it to other nodes' `connected_nodes` arrays

### Method 2: Create from Scratch
1. Right-click **NodeContainer** in Scene Tree
2. **Add Child Node** → search for **Area3D**
3. In the Inspector, set **Script** to `res://World/MAP/map_node_3d.gd`
4. Set all the export properties
5. Position it in the 3D viewport

## 🔗 Connecting Nodes

To connect two nodes (make a path between them):

1. Select the **source node** (e.g., Node_1A)
2. In Inspector, find **Connected Nodes** array
3. Click the **+** button to add an element
4. Set the value to: `NodePath("../Node_2A")`
   - Replace `Node_2A` with the target node name
5. The path line will appear when you run the scene

**Example:**
```
Node_1A connects to Node_2A and Node_2B:
Connected Nodes:
  [0]: NodePath("../Node_2A")
  [1]: NodePath("../Node_2B")
```

## 🗑️ Regenerating All Nodes

If you want to **start fresh** and regenerate all nodes:

1. Delete all nodes under **NodeContainer** in Scene Tree
2. Run `generate_nodes_editor.gd` again (File → Run)
3. Save the scene (Ctrl+S)

**Warning:** This will delete any manual edits you made!

## 🎮 Testing

After editing nodes:
1. Press **F6** to run the current scene
2. Your changes are immediately visible
3. No need to regenerate or recompile

## 📝 Node Types Reference

| Type | Description | Example |
|------|-------------|---------|
| `hub` | Portal hub (starting point) | PortalHub |
| `fight` | Combat encounter | Forest Guardian |
| `elite` | Harder combat, better rewards | Earth Warden |
| `boss` | Final boss battle | Terramaw |
| `shop` | Merchant/shop | Traveling Merchant |
| `rest` | Healing/rest site | Ancient Campfire |
| `explore` | Exploration event | Hidden Grove |
| `fireevent` | Fire elemental event | Burning Shrine |
| `waterevent` | Water elemental event | Mystic Pool |
| `windevent` | Wind elemental event | - |
| `earthevent` | Earth elemental event | - |

## 🐛 Troubleshooting

### "No nodes appear in Scene Tree"
- Make sure you ran the generator script
- Check that you **saved the scene** after running it
- Look in **NodeContainer** for the nodes

### "Nodes don't connect properly"
- Check the `connected_nodes` array syntax: `NodePath("../NodeName")`
- Make sure the target node name matches exactly
- Paths are relative to the parent (use `../`)

### "Changes don't appear when running"
- Save the scene (Ctrl+S) after editing
- Make sure you're editing the right scene (3DMAPSCENE.tscn)

## 💡 Tips

- **Use naming conventions**: Node_1A, Node_2B, etc. makes it easier to track layers
- **Keep connections logical**: Don't skip layers (Node_1A should connect to Node_2X, not Node_3X)
- **Test frequently**: Run the scene (F6) after making changes
- **Backup before regenerating**: If you have custom edits, duplicate the scene first
- **Use Inspector filters**: Filter by "MapNode3D" to see only nodes in Scene Tree

---

**Now you have full control over the map layout in the editor!** 🎉
