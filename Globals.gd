extends Node

const TUTORIAL_SKIP := true

# Set tutorial_stage to 999 when skip is enabled to bypass all stage checks
var tutorial_stage := 999.0 if TUTORIAL_SKIP else 0.0
var tutorial_completed := TUTORIAL_SKIP
var pending_post_tutorial_dialogue := false
var selected_leader: CardData = null

var unlocked_realms := {
	"earth": true,
	"fire": false,
	"water": false,
	"wind": false,
}
