class_name UIStyle
## Shared look for every DREAM PROTOCOL widget. Sizes scale with the accessibility text setting.

const TEXT := Color(0.93, 0.92, 0.88)
const DIM := Color(0.6, 0.6, 0.58)
const ACCENT := Color(0.95, 0.78, 0.45)
const DANGER := Color(0.8, 0.12, 0.1)
const PANEL := Color(0.02, 0.02, 0.025, 0.75)
const PAPER := Color(0.93, 0.9, 0.8)

static var _hand_font: Font
static var _other_hand_font: Font
static var _italic_font: Font


static func size(base: float) -> int:
	return int(round(base * Settings.text_scale))


static func label(text: String, base_size: float, color := TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size(base_size))
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func shadowed(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func panel_style(color := PANEL, pad := 14.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


static func flat_button(text: String, base_size: float) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size(base_size))
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_focus_color", TEXT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("pressed", empty)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.06)
	hover.border_width_left = 4
	hover.border_color = ACCENT
	hover.content_margin_left = 10
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	return b


## The player's own handwriting. Uses a handwriting font installed on the computer if there is one.
static func hand_font() -> Font:
	if _hand_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Noteworthy", "Bradley Hand", "Segoe Print", "Comic Neue", "Comic Sans MS"])
		f.font_italic = true
		_hand_font = f
	return _hand_font


## Somebody else's handwriting.
static func other_hand_font() -> Font:
	if _other_hand_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Chalkduster", "Marker Felt", "Ink Free", "Courier New"])
		_other_hand_font = f
	return _other_hand_font


static func italic_font() -> Font:
	if _italic_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
		f.font_italic = true
		_italic_font = f
	return _italic_font


static func ink(style: String) -> Color:
	match style:
		"Pressed": return Color(0.04, 0.06, 0.2)
		"Unknown": return Color(0.38, 0.04, 0.04)
		"Smudged": return Color(0.25, 0.27, 0.35, 0.55)
		_: return Color(0.08, 0.13, 0.38)


static func ink_font(style: String) -> Font:
	return other_hand_font() if style == "Unknown" else hand_font()
