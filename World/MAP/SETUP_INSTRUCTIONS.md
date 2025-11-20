# How to Set Up the New Earth Realm Map

Follow these steps to implement the comprehensive 22-node branching map system:

## Step 1: Run the Map Generator

1. Open your **earth_map_screen.tscn** in the Godot editor
2. Select the root **EarthMapScene** node
3. In the Inspector, temporarily attach the `map_generator.gd` script as a tool script
4. Add this code to the top of `map_generator.gd`:

```gdscript
@tool
extends Node

# ... rest of the script ...

func _ready():
	if Engine.is_editor_hint():
		var node_layer = get_node_or_null("MapRoot/NodeLayer")
		if node_layer:
			print("🗺️ Starting map generation...")
			clear_old_nodes(node_layer)
			await get_tree().create_timer(0.5).timeout
			generate_map(node_layer)
```

5. Save the scene - this will trigger the generator to create all nodes
6. After generation completes, remove the map_generator script from EarthMapScene
7. Save the scene again to preserve the generated nodes

## Step 2: Verify Node Creation

Check that the following nodes were created in `MapRoot/NodeLayer`:
- ✅ PortalHub (already exists)
- ✅ Node_1A, Node_1B, Node_1C (Layer 1 - 3 nodes)
- ✅ Node_2A, Node_2B, Node_2C, Node_2D (Layer 2 - 4 nodes)
- ✅ Node_3A, Node_3B, Node_3C (Layer 3 - 3 nodes)
- ✅ Node_4A, Node_4B, Node_4C (Layer 4 - 3 nodes)
- ✅ Node_5A, Node_5B (Layer 5 - 2 elites)
- ✅ Node_6A, Node_6B, Node_6C (Layer 6 - 3 nodes)
- ✅ Node_BOSS (Layer 7 - boss)

**Total: 22 nodes**

## Step 3: Adjust Camera Limits

The map now extends much further vertically. Update the MapCamera limits in earth_map_screen.tscn:

```gdscript
[node name="MapCamera" type="Camera2D" parent="."]
position = Vector2(370, 700)  # Center on middle of map
limit_left = -75
limit_top = -350
limit_right = 1400
limit_bottom = 1300  # Extended to fit boss node at Y:1150
position_smoothing_enabled = true
```

## Step 4: Extend Map Background

The map background may need to be extended:

1. Create or use a taller background image for EarthMap.png
2. Or extend the GreenBackDrop ColorRect to cover the new area:

```
offset_bottom = 1400  # Instead of current 6983
```

## Step 5: Test the Map

1. Run the game and enter the Earth Realm
2. Test each path:
   - **Left path**: Hub → 1A → 2A → 3A → 4A → 5A → 6A → BOSS
   - **Middle paths**: Various combinations through center nodes
   - **Right path**: Hub → 1C → 2D → 3C → 4C → 5B → 6C → BOSS

3. Verify node types work correctly:
   - ✅ Fights trigger Arena3D with correct enemies
   - ✅ Shops display shop UI (placeholder for now)
   - ✅ Rest sites show rest options (placeholder for now)
   - ✅ Events trigger event popups
   - ✅ Elites are harder fights with better rewards
   - ✅ Boss is the ultimate challenge
   - ✅ Portal hub returns to main hub

## Step 6: Implement Missing Systems (Optional Enhancements)

### Shop System
```gdscript
func _open_shop(node: MapNode):
	# Show shop UI with purchasable cards
	var shop_ui = preload("res://UI/Shop.tscn").instantiate()
	add_child(shop_ui)
	shop_ui.populate_shop(node.rewards)
```

### Rest Site System
```gdscript
func _show_rest_site(node: MapNode):
	# Show rest UI with options: Heal, Upgrade card, Remove card
	var rest_ui = preload("res://UI/RestSite.tscn").instantiate()
	add_child(rest_ui)
```

### Event System
```gdscript
func _show_event(node: MapNode):
	# Show event popup with story choices
	var event_ui = preload("res://UI/EventPopup.tscn").instantiate()
	add_child(event_ui)
	event_ui.show_event(node.encounter_type, node.description)
```

## Step 7: Balance and Polish

1. **Difficulty Tuning**: Adjust enemy decks in map_generator.gd based on playtesting
2. **Reward Balance**: Ensure elite/boss nodes give appropriately powerful rewards
3. **Visual Polish**: Add unique textures for elite and boss nodes
4. **Sound Effects**: Add audio cues for different node types
5. **Particle Effects**: Add visual flair to elite/boss nodes

## Step 8: Add More Realms

Once the Earth Realm is polished, you can duplicate this system for other realms:
- Fire Realm Map
- Water Realm Map
- Wind Realm Map
- Shadow Realm Map

Each with unique enemies, events, and a climactic boss!

---

## Troubleshooting

### "Nodes aren't connecting properly"
- Check that node names in `node_config` match exactly
- Verify NodePath format is correct: `"../NodeName"`

### "Camera doesn't follow properly"
- Increase camera limits (bottom should be > 1300)
- Check camera position_smoothing is enabled

### "Boss node isn't visible"
- Extend the background ColorRect
- Adjust camera zoom limits to allow zooming out more

### "Nodes overlap"
- Adjust X/Y positions in map_generator.gd
- Use Godot's 2D editor to visually reposition nodes

---

## Next Steps

After the map is working:
1. ✅ Add unique boss mechanics and abilities
2. ✅ Create elite-specific card rewards
3. ✅ Implement shop currency system
4. ✅ Add map progression saving/loading
5. ✅ Create procedurally generated maps for replayability
6. ✅ Add daily challenges and special events

Happy mapping! 🗺️✨
