extends Control

@onready var card_row_1: HBoxContainer = $CardRow1
@onready var card_row_2: HBoxContainer = $CardRow2
@onready var card_row_3: HBoxContainer = $CardRow3

const CARDS_PER_ROW := 8
const CARD_PATHS := {
	"DIRT":               "res://Cards/Monster Cards/Dirt.tres",
	"GOBLIN":             "res://Cards/Monster Cards/Goblin.tres",
	"IMP":                "res://Cards/Monster Cards/Imp.tres",
	"FYSH":               "res://Cards/Monster Cards/Fysh.tres",
	"NAGA":               "res://Cards/Monster Cards/Naga of the Pyre.tres",
	"COLD_SLOTH":         "res://Cards/Monster Cards/Cold_Sloth.tres",
	"LAVA_HARE":          "res://Cards/Monster Cards/Lava_Hare.tres",
	"FOREST_FAE":         "res://Cards/Monster Cards/Forest_Fae.tres",
	"FIREBALL":           "res://Cards/Spell Cards/Fireball.tres",
	"LYZARD":             "res://Cards/Monster Cards/Aqua Lyzard.tres",
	"ERUPTION":           "res://Cards/Spell Cards/Eruption.tres",
	"DRAKE_OF_EMERALD":   "res://Cards/Monster Cards/Drake of Emerald.tres",
	"FLAME_FAE":          "res://Cards/Monster Cards/Flame_Fae.tres",
	"AXO_THE_KNIGHT":     "res://Cards/Monster Cards/Axo The Knight.tres",
	"STONE_FAE":          "res://Cards/Monster Cards/Stone_Fae.tres",
	"FINN":                 "res://Cards/Monster Cards/Finn.tres",
	"FALCREEP":             "res://Cards/Monster Cards/Falcreep.tres",
	"SNAPTRAP":             "res://Cards/Monster Cards/Snaptrap.tres",
	"MOLTEN_PIG":           "res://Cards/Monster Cards/Molten_Pig.tres",
	"NINJOAD":              "res://Cards/Monster Cards/Ninjoad.tres",
	"BOOGLES":              "res://Cards/Monster Cards/Boogles.tres",
	"FUNGOO":               "res://Cards/Monster Cards/Fungoo.tres",
	"ORB_OF_DARKNESS":      "res://Cards/Spell Cards/Orb_Of_Darkness.tres",
	"SHADOW_CANDLES":       "res://Cards/Spell Cards/Shadow_Candles.tres",
	"JESTER_OF_FLAMES":     "res://Cards/Monster Cards/Jester_of_Flames.tres",
	"VOIDLING_ERO":         "res://Cards/Monster Cards/Voidling_Ero.tres",
	"MUSHMONK":             "res://Cards/Monster Cards/Mushmonk.tres",
	"ZEI_PANDA":            "res://Cards/Monster Cards/Zei_Panda.tres",
	"YORG_ARCHER":          "res://Cards/Monster Cards/Yorg_Archer.tres",
	"CONFLAGURATION_BLADE": "res://Cards/Spell Cards/Conflaguration_Blade.tres",
	"TIDAL_WAVE":           "res://Cards/Spell Cards/Tidal_Wave.tres",
	"AQUA_WHIP":            "res://Cards/Spell Cards/Aqua_whip.tres",
	#"":                  "res://Cards/Monster Cards/.tres",
}
var CardUICutscene := preload("res://UI/CardUICutscene.tscn")

var cutscene_cards : Array[CardData] = []

func _ready() -> void:
	for key in CARD_PATHS.keys():
		var path = CARD_PATHS[key]
		if ResourceLoader.exists(path):
			var cd = load(path)
			if cd:
				cutscene_cards.append(cd)
		else:
			push_warning("[CardLoop] Card resource not found: " + path)

	_spawn_row_cards(card_row_1)
	_spawn_row_cards(card_row_2)
	_spawn_row_cards(card_row_3)


func _spawn_row_cards(row: HBoxContainer) -> void:
	# duplicate & shuffle so we can pull unique cards
	var pool := cutscene_cards.duplicate()
	pool.shuffle()

	# how many we can safely take
	var amount = min(CARDS_PER_ROW, pool.size())

	for i in range(amount):
		var inst = CardUICutscene.instantiate()
		inst.card_data = pool[i]
		row.add_child(inst)
		inst.refresh()
