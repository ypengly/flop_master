class_name UiKit
extends RefCounted
## Shared cartoon UI styling and widget helpers. Every screen is built from code with these,
## so look and feel stay consistent and there are no external theme assets.

const COL_BG := Color(0.12, 0.10, 0.25)
const COL_PANEL := Color(0.20, 0.17, 0.42)
const COL_ACCENT := Color(1.0, 0.78, 0.15)
const COL_GOOD := Color(0.35, 0.9, 0.5)
const COL_BAD := Color(1.0, 0.35, 0.4)
const COL_TEXT := Color(1, 1, 1)
const COL_MUTED := Color(0.75, 0.72, 0.95)


static func style(bg: Color, radius := 18, border := Color(0, 0, 0, 0.0), border_w := 0, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 4)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_default_font_size(22)
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_color("font_outline_color", "Label", Color(0.1, 0.05, 0.25))
	t.set_constant("outline_size", "Label", 4)
	for cls in ["Button", "CheckButton", "CheckBox"]:
		t.set_color("font_color", cls, COL_TEXT)
		t.set_color("font_hover_color", cls, Color(1, 1, 0.8))
		t.set_color("font_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_disabled_color", cls, Color(0.6, 0.6, 0.7))
	t.set_stylebox("normal", "Button", style(Color(0.38, 0.30, 0.78), 16, Color(0.6, 0.5, 1.0), 3))
	t.set_stylebox("hover", "Button", style(Color(0.5, 0.4, 0.95), 16, COL_ACCENT, 3))
	t.set_stylebox("pressed", "Button", style(Color(0.30, 0.24, 0.62), 16, COL_ACCENT, 3, false))
	t.set_stylebox("disabled", "Button", style(Color(0.25, 0.23, 0.35), 16, Color(0.3, 0.3, 0.4), 2, false))
	t.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), 16, COL_ACCENT, 4, false))
	t.set_stylebox("panel", "PanelContainer", style(COL_PANEL, 24, Color(0.5, 0.45, 0.9), 4))
	t.set_stylebox("background", "ProgressBar", style(Color(0.1, 0.08, 0.2, 0.8), 10, Color(0, 0, 0, 0), 0, false))
	t.set_stylebox("fill", "ProgressBar", style(COL_GOOD, 10, Color(0, 0, 0, 0), 0, false))
	return t


static func label(text: String, size := 22, color := COL_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, min_size := Vector2(260, 56), size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func() -> void:
		AudioManager.play("click", 0.8)
		callback.call())
	b.mouse_entered.connect(func() -> void: AudioManager.play("click", 0.25, 1.4))
	return b


static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func fullscreen_dim(alpha := 0.6) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.03, 0.02, 0.12, alpha)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Wrap content in a centered panel with a title; returns [root_control, content_vbox].
static func dialog(title: String, min_size := Vector2(560, 0)) -> Array:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := panel(min_size)
	center.add_child(p)
	var v := vbox(14)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_child(v)
	p.add_child(margin)
	v.add_child(label(title, 40, COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	return [center, v]


static func medal_color(medal: String) -> Color:
	match medal:
		"gold": return Color(1.0, 0.84, 0.2)
		"silver": return Color(0.85, 0.88, 0.95)
		"bronze": return Color(0.85, 0.55, 0.3)
	return Color(0.4, 0.4, 0.5)


static func fmt_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	var cs := int((t - floorf(t)) * 100.0)
	return "%d:%02d.%02d" % [m, s, cs]
