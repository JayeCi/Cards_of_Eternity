# Cards of Eternity - Earth Realm Map Design
## AAA Professional Map Layout (Slay the Spire Inspired)

### Map Structure Overview
- **Total Nodes**: 22 nodes across 8 layers
- **Design Philosophy**: Branching paths with meaningful choices
- **Progression**: Easy → Medium → Hard → Elite → Boss

---

## Layer-by-Layer Breakdown

### **Layer 0: Starting Point**
- **PortalHub** (hub) - Can return here to go back to main hub

### **Layer 1: First Encounters** (Y: 540-560)
Easy combat encounters to learn the ropes
- **Node_1A** (fight) - "Forest Guardian" - X: 240, rewards: 1 card
- **Node_1B** (fight) - "Wandering Imp" - X: 350, rewards: 1 card
- **Node_1C** (fight) - "Rocky Golem" - X: 460, rewards: 1 card

### **Layer 2: Diverging Paths** (Y: 640-660)
Mix of combat and rewards - player chooses their path
- **Node_2A** (fireevent) - "Burning Shrine" - X: 200, rewards: 1-2 cards
- **Node_2B** (fight) - "Goblin Raider" - X: 310, rewards: 1 card
- **Node_2C** (explore) - "Hidden Grove" - X: 420, rewards: 1-2 cards
- **Node_2D** (fight) - "Earth Elemental" - X: 520, rewards: 1 card

### **Layer 3: Mid-Game Choices** (Y: 740-760)
Strategic decision points
- **Node_3A** (shop) - "Traveling Merchant" - X: 260
- **Node_3B** (fight) - "Veteran Fighter" - X: 370, difficulty: 2, rewards: 2 cards
- **Node_3C** (rest) - "Ancient Campfire" - X: 470

### **Layer 4: Escalating Challenge** (Y: 840-860)
Tougher encounters before elites
- **Node_4A** (fight) - "Beast Tamer" - X: 310, difficulty: 2, rewards: 2 cards
- **Node_4B** (waterevent) - "Mystic Pool" - X: 420, rewards: 2 cards
- **Node_4C** (fight) - "Wind Dancer" - X: 520, difficulty: 2, rewards: 2 cards

### **Layer 5: Elite Encounters** (Y: 940-960)
Dangerous elites with better rewards
- **Node_5A** (elite) - "Earth Warden" - X: 280, difficulty: 3, rewards: 2-3 cards
- **Node_5B** (elite) - "Flame Champion" - X: 420, difficulty: 3, rewards: 2-3 cards

### **Layer 6: Final Preparation** (Y: 1040-1060)
Last chance to prep before boss
- **Node_6A** (shop) - "Final Outpost" - X: 320
- **Node_6B** (rest) - "Sacred Grove" - X: 400
- **Node_6C** (explore) - "Ancient Ruins" - X: 480, rewards: 2 cards

### **Layer 7: Boss Encounter** (Y: 1140)
Climactic final battle
- **Node_BOSS** (boss) - "Earth Realm Guardian" - X: 380, difficulty: 5, rewards: 3-4 legendary cards

---

## Node Connections (Branching Paths)

```
PortalHub → {Node_1A, Node_1B, Node_1C}

Node_1A → {Node_2A, Node_2B}
Node_1B → {Node_2B, Node_2C}
Node_1C → {Node_2C, Node_2D}

Node_2A → {Node_3A, Node_3B}
Node_2B → {Node_3A, Node_3B, Node_3C}
Node_2C → {Node_3B, Node_3C}
Node_2D → {Node_3C}

Node_3A → {Node_4A, Node_4B}
Node_3B → {Node_4A, Node_4B, Node_4C}
Node_3C → {Node_4B, Node_4C}

Node_4A → {Node_5A}
Node_4B → {Node_5A, Node_5B}
Node_4C → {Node_5B}

Node_5A → {Node_6A, Node_6B}
Node_5B → {Node_6B, Node_6C}

Node_6A → {Node_BOSS}
Node_6B → {Node_BOSS}
Node_6C → {Node_BOSS}
```

---

## Node Type Distribution
- **Combat (fight)**: 9 nodes
- **Elite**: 2 nodes
- **Boss**: 1 node
- **Shop**: 2 nodes
- **Rest**: 2 nodes
- **Events (fire/water/explore)**: 4 nodes
- **Hub**: 1 node

**Total: 22 nodes** with multiple viable paths from start to boss.

---

## Rewards Philosophy
- **Basic fights**: 1 card
- **Harder fights**: 2 cards
- **Elite fights**: 2-3 cards (higher rarity)
- **Boss**: 3-4 cards (rare/legendary)
- **Events**: 1-2 cards (varied rarity)
- **Shops**: Purchase cards with gold (to be implemented)
- **Rest**: Heal/upgrade (no cards)

---

## Strategic Considerations
1. **Multiple Paths**: Players can take different routes each playthrough
2. **Risk/Reward**: Elites are harder but give better rewards
3. **Resource Management**: Shops and rest sites require strategic placement
4. **Difficulty Curve**: Gradually increases from Layer 1 to Boss
5. **Replayability**: Different node combinations each run creates variety
