extends Node
## Language: English (the game's own text) or Korean (data/Lang_ko.json through LocTranslation).
## Settings.language: 0 = English, 1 = 한국어. Every label follows the switch at once (auto-translation);
## text drawn by hand goes through Loc.t(). Korean text uses the fonts in fonts/ (subsets of NAVER Nanum fonts, SIL Open Font License).

const LOCALES := ["en", "ko"]
const NAMES := ["English", "한국어"]

var korean_font: Font
var korean_hand: Font
var _tr: LocTranslation
var _lang := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--lang=ko"):
		Settings.language = 1.0
	elif OS.get_cmdline_user_args().has("--lang=en"):
		Settings.language = 0.0
	_tr = LocTranslation.new()
	_tr.locale = "ko"
	_tr.log_misses = OS.get_cmdline_user_args().has("--loc-misses")
	_tr.load_file("res://data/Lang_ko.json")
	TranslationServer.add_translation(_tr)
	korean_font = load("res://fonts/dp_korean_gothic.ttf") as Font
	korean_hand = load("res://fonts/dp_korean_pen.ttf") as Font
	if korean_font:
		var f := ThemeDB.fallback_font
		var fb := f.fallbacks
		fb.append(korean_font)
		f.fallbacks = fb
	_apply()


func _process(_delta: float) -> void:
	if clampi(int(Settings.language), 0, 1) != _lang:
		_apply()


func _apply() -> void:
	_lang = clampi(int(Settings.language), 0, 1)
	TranslationServer.set_locale(LOCALES[_lang])


func korean() -> bool:
	return _lang == 1


## For text that isn't in a label (drawn by hand).
func t(s: String) -> String:
	return TranslationServer.translate(s) if _lang == 1 else s


## A font with Korean behind it, for fonts made in code.
func with_korean(f: Font, hand := false) -> Font:
	var k: Font = korean_hand if hand and korean_hand else korean_font
	if f != null and k != null and not f.fallbacks.has(k):
		var fb := f.fallbacks
		fb.append(k)
		f.fallbacks = fb
	return f
