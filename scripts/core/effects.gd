class_name Effects
## Data-driven effect strings used by dialogue, notebook rules and story scripts.
##
##   fear:+10 | stability:-10          change DREAD inputs (positive fear is scaled by the zone)
##   flag:name | unflag:name           story flags
##   rule:break:<id>                   break a notebook rule (runs its onBreak effects)
##   notebook:write|reveal|hide:<id>   notebook changes (reveal = appears on next open)
##   notebook:rewrite:<id>:<variant>
##   observer:closer                   the Observer comes nearer (only while unobserved)
##   thought:<text> | hint:<text>      on-screen text
##   unlock:<manifest id>
##   manifest:give                     hand the held object to the current speaker
##   sound:page|knock|thud|chime


static func apply_all(effects: Array, speaker: Node = null) -> void:
	for e in effects:
		apply(str(e), speaker)


static func apply(effect: String, speaker: Node = null) -> void:
	effect = effect.strip_edges()
	if effect.is_empty():
		return
	var parts := effect.split(":", true, 3)
	var verb := parts[0].to_lower()
	var a1 := parts[1] if parts.size() > 1 else ""
	var a2 := parts[2] if parts.size() > 2 else ""
	var a3 := parts[3] if parts.size() > 3 else ""
	var rest := effect.substr(effect.find(":") + 1).strip_edges()
	var player = Game.player

	match verb:
		"fear":
			if player: player.dread.add_fear(a1.to_float(), "effect")
		"stability":
			if player: player.dread.add_stability(a1.to_float())
		"flag":
			Game.set_flag(a1)
		"unflag":
			Game.clear_flag(a1)
		"rule":
			if a1 == "break": Notebook.break_rule(a2)
		"notebook":
			match a1:
				"write": Notebook.write(a2)
				"reveal": Notebook.reveal_on_next_open(a2)
				"hide": Notebook.hide_rule(a2)
				"rewrite": Notebook.rewrite(a2, a3)
				_: push_warning("Unknown notebook effect: " + effect)
		"observer":
			if Game.zone: Game.zone.observer_event(a1)
		"thought":
			Game.hud.show_thought(rest, 4.0)
		"hint":
			Game.hud.show_hint(rest, 6.0)
		"unlock":
			if player: player.manifestation.unlock(a1)
		"manifest":
			if a1 == "give" and player and speaker and speaker.has_method("get_hand"):
				player.manifestation.give_held_to(speaker.get_hand())
		"sound":
			Sfx.play(a1)
		_:
			push_warning("Unknown effect: " + effect)


## A dialogue condition: a story flag, or "holding:<manifest id>". Empty = true.
static func check(condition: String) -> bool:
	if condition.is_empty():
		return true
	if condition.begins_with("holding:"):
		return Game.player != null and Game.player.manifestation.is_holding(condition.substr(8))
	return Game.has_flag(condition)
