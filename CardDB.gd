extends Node
class_name CardDB

# ====================================================================
# 🗃️ CARD DATABASE — Organized by Category
# ====================================================================
# This structure keeps all card paths grouped and easy to maintain.
# Each category is separated, alphabetized, and visually clear.
# ====================================================================

const PATH := {

	# ================================================================
	# 🐾 MONSTER CARDS — EARTH & NATURE
	# ================================================================
	"DIRT":                     "res://Cards/Monster Cards/Dirt.tres",
	"FOREST_FAE":               "res://Cards/Monster Cards/Forest_Fae.tres",
	"STONE_FAE":                "res://Cards/Monster Cards/Stone_Fae.tres",
	"STONE_GUARD":              "res://Cards/Monster Cards/Stone_Guard.tres",
	"STONEHAMMER_GUARDIAN":     "res://Cards/Monster Cards/Stonehammer_Guardian.tres",
	"EARTHREALM_MACHINIST":     "res://Cards/Monster Cards/Earthrealm_Machinist.tres",
	"PORCU-BEAST":              "res://Cards/Monster Cards/Porcu-Beast.tres",

	# ================================================================
	# 🔥 MONSTER CARDS — FIRE REALM
	# ================================================================
	"FLAME_FAE":                "res://Cards/Monster Cards/Flame_Fae.tres",
	"LAVA_HARE":                "res://Cards/Monster Cards/Lava_Hare.tres",
	"JESTER_OF_FLAMES":         "res://Cards/Monster Cards/Jester_of_Flames.tres",
	"FYRA":                     "res://Cards/Monster Cards/Fyra.tres",
	"MOLTEN_PIG":               "res://Cards/Monster Cards/Molten_Pig.tres",

	# ================================================================
	# 🌊 MONSTER CARDS — WATER REALM
	# ================================================================
	"LYZARD":                   "res://Cards/Monster Cards/Aqua Lyzard.tres",
	"FYSH":                     "res://Cards/Monster Cards/Fysh.tres",
	"DRAKE_OF_EMERALD":         "res://Cards/Monster Cards/Drake of Emerald.tres",
	"ICE_CRAB":                 "res://Cards/Monster Cards/Ice_Crab.tres",
	"COLD_SLOTH":               "res://Cards/Monster Cards/Cold_Sloth.tres",

	# ================================================================
	# 🌬️ MONSTER CARDS — WIND REALM
	# ================================================================
	"CLOUD_MONKEY":             "res://Cards/Monster Cards/Cloud_Monkey.tres",
	"FALCREEP":                 "res://Cards/Monster Cards/Falcreep.tres",
	"GALE_SPIRIT":              "res://Cards/Monster Cards/Gale_Spirit.tres",

	# ================================================================
	# ☠️ MONSTER CARDS — SHADOW / DARK
	# ================================================================
	"VOIDLING_ERO":             "res://Cards/Monster Cards/Voidling_Ero.tres",
	"PLAGUE_SENTINEL":          "res://Cards/Monster Cards/Plague_Sentinel.tres",
	"BONE_WARRIOR_RACOON":      "res://Cards/Monster Cards/Bone_Warrior_Raccoon.tres",
	"BONEHORN":                 "res://Cards/Monster Cards/Bonehorn.tres",

	# ================================================================
	# 🪓 MONSTER CARDS — MIGHT / FIGHTERS
	# ================================================================
	"GOBLIN":                   "res://Cards/Monster Cards/Goblin.tres",
	"IMP":                      "res://Cards/Monster Cards/Imp.tres",
	"NAGA":                     "res://Cards/Monster Cards/Naga of the Pyre.tres",
	"AXO_THE_KNIGHT":           "res://Cards/Monster Cards/Axo The Knight.tres",
	"SNAPTRAP":                 "res://Cards/Monster Cards/Snaptrap.tres",
	"BOOGLES":                  "res://Cards/Monster Cards/Boogles.tres",
	"FUNGOO":                   "res://Cards/Monster Cards/Fungoo.tres",
	"FINN":                     "res://Cards/Monster Cards/Finn.tres",
	"NINJOAD":                  "res://Cards/Monster Cards/Ninjoad.tres",
	"MUSHMONK":                 "res://Cards/Monster Cards/Mushmonk.tres",
	"ZEI_PANDA":                "res://Cards/Monster Cards/Zei_Panda.tres",
	"YORG_ARCHER":              "res://Cards/Monster Cards/Yorg_Archer.tres",
	"MINOTAUR_WARLORD":         "res://Cards/Monster Cards/Minotaur_Warlord.tres",

	# ================================================================
	# 🔮 SPELL CARDS — ELEMENTAL / OFFENSIVE
	# ================================================================
	"FIREBALL":                 "res://Cards/Spell Cards/Fireball.tres",
	"ERUPTION":                 "res://Cards/Spell Cards/Eruption.tres",
	"TIDAL_WAVE":               "res://Cards/Spell Cards/Tidal_Wave.tres",
	"AQUA_WHIP":                "res://Cards/Spell Cards/Aqua_whip.tres",
	"PERMAFROST":               "res://Cards/Spell Cards/Permafrost.tres",
	"TSUNAMI":                  "res://Cards/Spell Cards/Tsunami.tres",
	"ENRAGING_FOREST":          "res://Cards/Spell Cards/Enraging_Forest.tres",
	"WIND_ARMOR":               "res://Cards/Spell Cards/Wind_Armor.tres",
	"ACORN_OF_LIFE":            "res://Cards/Spell Cards/Acorn_of_Life.tres",
	
	# ================================================================
	# 🌑 SPELL CARDS — DARK / ARCANE
	# ================================================================
	"ORB_OF_DARKNESS":          "res://Cards/Spell Cards/Orb_Of_Darkness.tres",
	"ORB_OF_FROST":             "res://Cards/Spell Cards/Orb of Frost.tres",
	"CONFLAGURATION_BLADE":     "res://Cards/Spell Cards/Conflaguration_Blade.tres",
	"SINKHOLE":                 "res://Cards/Spell Cards/Sinkhole.tres",
	# ================================================================
	# 🎓 SPECIAL / TUTORIAL
	# ================================================================
	"TUTORIAL_GOBLIN":          "res://Cards/Monster Cards/Tutorial_Goblin.tres",
}

# ====================================================================
# 🔍 Lookup Function
# ====================================================================
static func lookup(name: String) -> String:
	return PATH.get(name, "")
