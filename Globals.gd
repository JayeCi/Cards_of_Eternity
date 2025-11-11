extends Node

var tutorial_stage := 0.0

var tutorial_completed := false
var pending_post_tutorial_dialogue := false
var selected_leader: CardData = null

var unlocked_realms := {
	"earth": true,
	"fire": false,
	"water": false,
	"wind": false,
}
