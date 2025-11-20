# Map Generator Troubleshooting

## "I only see PortalHub, where are the other nodes?"

**This is NORMAL!** Here's why:

### In the Editor:
- Only PortalHub appears visible
- Other nodes ARE created, but invisible
- The `map_screen.gd` script doesn't run in the editor
- Node visibility is controlled by `_update_node_visuals()` which runs at runtime

### To See All Nodes:

**Option 1: Run the Game** ⭐ (Recommended)
1. Save the scene (`Ctrl+S`)
2. Press `F5` to run the game
3. Navigate to the Earth Realm
4. All 22 nodes will now be visible!

**Option 2: Check in Scene Tree**
1. In the Scene panel, expand: `EarthMapScene → MapRoot → NodeLayer`
2. You should see all nodes listed:
   - PortalHub
   - Player
   - Node_1A, Node_1B, Node_1C
   - Node_2A, Node_2B, Node_2C, Node_2D
   - etc... (22 total)
3. Click on each node to see them highlight in the 2D viewport

---

## "LineDrawer is spamming errors"

**Fixed!** I updated `line_drawer.gd` to:
- Check if `map_core` exists before drawing
- Use `get_node_or_null()` instead of `get_node()`
- Validate nodes before accessing them

If you still see errors:
1. Make sure you saved the updated `line_drawer.gd`
2. Close and reopen the scene
3. The errors should stop

---

## "Return to Hub button is grayed out"

This happens when PortalHub's `battle_completed` is not set.

**Fixed!** The generator now sets:
```gdscript
existing.encounter_type = "hub"
existing.battle_completed = true
existing.is_completed = true
```

To apply the fix:
1. Run the generator again (`Ctrl+Shift+X` → `generate_map_NOW.gd`)
2. Save the scene
3. Close and reopen the scene
4. Run the game

---

## How Node Visibility Works

### At Runtime (When Game is Running):

The `map_screen.gd` script:

1. **Gathers all nodes** in `_ready()`:
   ```gdscript
   for child in node_layer.get_children():
       if child is MapNode:
           all_nodes.append(child)
   ```

2. **Updates reachability** via `_update_node_reachability()`:
   - PortalHub: Always reachable
   - Connected nodes: Reachable if current node's battle is completed

3. **Updates visuals** via `_update_node_visuals()`:
   ```gdscript
   if n.is_current:
       n.modulate = Color(1, 1, 1, 1)      # Bright (current node)
   elif n.is_completed:
       n.modulate = Color(0.6, 0.6, 0.6, 1)  # Gray (completed)
   elif n.is_reachable:
       n.modulate = Color(1, 1, 1, 0.9)    # Slightly dim (reachable)
   else:
       n.modulate = Color(0.4, 0.4, 0.4, 0.3)  # Very dim (unreachable)
   ```

### In the Editor:

- Script doesn't run
- Nodes use default modulate `Color(1, 1, 1, 1)`
- Some nodes may have modulate set in their scene file

---

## Verification Checklist

After running the generator, verify:

✅ **Scene Tree Check:**
- [ ] Open Scene tree
- [ ] Expand `MapRoot/NodeLayer`
- [ ] See 23 children (PortalHub, Player, + 21 nodes)

✅ **Node Properties Check:**
- [ ] Click on Node_1A in scene tree
- [ ] In Inspector, verify:
  - Position is around (240, 550)
  - Size is around (50, 50)
  - `encounter_type` = "fight"
  - `enemy_name` = "Forest Guardian"
  - `connected_nodes` has 2 entries

✅ **PortalHub Check:**
- [ ] Click PortalHub in scene tree
- [ ] Verify `encounter_type` = "hub"
- [ ] Verify `battle_completed` = true
- [ ] Verify `is_completed` = true
- [ ] Verify `connected_nodes` has 3 entries (Node_1A, Node_1B, Node_1C)

✅ **Runtime Check:**
- [ ] Save scene
- [ ] Run game (F5)
- [ ] Navigate to Earth Realm
- [ ] See multiple nodes visible on map
- [ ] Click PortalHub - should show return option
- [ ] Click Node_1A - should show fight encounter

---

## Common Issues

### "Nodes are overlapping and huge"
- Old issue - fixed in current version
- If you see this, re-run the generator

### "Can't click on nodes"
- The map_screen handles clicks at runtime
- In editor, clicking does nothing (normal)
- Run the game to test clicking

### "Camera doesn't show all nodes"
- Update camera limits in `earth_map_screen.tscn`:
  ```
  [node name="MapCamera"]
  limit_bottom = 1300  # Instead of 830
  ```

### "Background doesn't cover all nodes"
- Boss node is at Y:1150
- Extend background ColorRect or texture

---

## Still Having Issues?

1. **Delete all nodes** (except PortalHub and Player)
2. **Run generator** again
3. **Save scene**
4. **Close and reopen** Godot
5. **Run the game** to verify

If problems persist, check the Output console for error messages and share them for debugging.
