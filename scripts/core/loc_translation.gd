class_name LocTranslation
extends Translation
## Korean, from data/Lang_ko.json: {"strings": {english: korean}, "patterns": [[english with %s/%d, korean]]}.
## Godot asks this for every label, button and 3D label text while the locale is "ko" (auto-translation),
## so the game's code keeps writing English. Handles, in order: exact text; text built with % or +
## (patterns, the captured parts translated too); multi-line text, line by line. Unknown text stays English.

var strings := {}
var patterns: Array = []         # [RegEx, korean template]
var misses := {}
var log_misses := false
var _memo := {}
static var _counter := RegEx.create_from_string("\\{([a-z_]+)\\}")


func load_file(path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("Loc: could not read " + path)
		return
	strings = data.get("strings", {})
	for p in data.get("patterns", []):
		var rx := RegEx.create_from_string("^" + _to_regex(p[0]) + "$")
		if rx.is_valid():
			patterns.append([rx, p[1], _literal_len(p[0])])
	# keys with %s / %d / {counter} in them are patterns too
	for k in strings.keys():
		if String(k).contains("%s") or String(k).contains("%d") or _counter.search(String(k)) != null:
			var rx := RegEx.create_from_string("^" + _to_regex(k) + "$")
			if rx.is_valid():
				patterns.append([rx, strings[k], _literal_len(k)])
	# the most specific first: "Talk to the residents ({talked}/3)" before "Talk to %s", "%d. Far below..." before "%d. %s"
	patterns.sort_custom(func(a, b): return a[2] > b[2])


static func _literal_len(k: String) -> int:
	return _counter.sub(k.replace("%s", "").replace("%d", ""), "", true).length()


static func _to_regex(s: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "{":
			var close := s.find("}", i)
			if close > i and s.substr(i + 1, close - i - 1).is_valid_identifier():
				out += "(?<%s>-?\\d+)" % s.substr(i + 1, close - i - 1)
				i = close + 1
				continue
		if c == "%" and i + 1 < s.length():
			var n := s[i + 1]
			if n == "s":
				out += "(.+?)"
				i += 2
				continue
			if n == "d":
				out += "(-?\\d+)"
				i += 2
				continue
			if n == "%":
				out += "%"
				i += 2
				continue
		if "\\^$.|?*+()[]{}".contains(c):
			out += "\\" + c
		else:
			out += c
		i += 1
	return out


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if _memo.has(s):
		return _memo[s]
	var out := _translate(s)
	if _memo.size() > 4000:
		_memo.clear()
	_memo[s] = out
	return out


func _translate(s: String) -> String:
	if s.strip_edges() == "" or not _has_latin(s):
		return s
	if strings.has(s):
		return strings[s]
	for p in patterns:
		var m: RegExMatch = (p[0] as RegEx).search(s)
		if m:
			var out: String = p[1]
			for nm in m.names:
				out = out.replace("{%s}" % nm, m.get_string(nm))
			for gi in range(1, m.get_group_count() + 1):
				var part := m.get_string(gi)
				out = out.replace("{%d}" % gi, _translate(part))
			# %s / %d placeholders, in order
			var gi2 := 1
			while gi2 <= m.get_group_count() and (out.contains("%s") or out.contains("%d")):
				var part2 := _translate(m.get_string(gi2))
				var at_s := out.find("%s")
				var at_d := out.find("%d")
				var at := at_s if at_d < 0 or (at_s >= 0 and at_s < at_d) else at_d
				out = out.substr(0, at) + part2 + out.substr(at + 2)
				gi2 += 1
			return out
	if s.contains("\n"):
		var lines := s.split("\n")
		var changed := false
		for i in lines.size():
			var t := _translate(lines[i])
			changed = changed or t != lines[i]
			lines[i] = t
		if changed:
			return "\n".join(lines)
	# surrounding spaces or punctuation the table doesn't have
	var core := s.strip_edges()
	if core != s and strings.has(core):
		return s.replace(core, strings[core])
	if log_misses and not misses.has(s) and not _has_hangul(s):
		misses[s] = true
		print("LOC MISS: ", s.c_escape())
	return s


static func _has_hangul(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) >= 0xAC00 and s.unicode_at(i) <= 0xD7A3:
			return true
	return false


static func _has_latin(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			return true
	return false
