class_name Ui
extends RefCounted
## Small helpers for the chunky pixel UI.

const PANEL_BG := Color(0.11, 0.09, 0.16, 0.88)
const GOLD := Color("ffd45a")


static func label(text: String, size := 24, color := Color.WHITE, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Art.font(true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Art.OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func title(text: String, size := 48, color := Color.WHITE, outline := 12) -> Label:
	var l := label(text, size, color, outline)
	l.add_theme_font_override("font", Art.title_font())
	return l


static func body(text: String, size := 20, color := Color("e8e2f0")) -> Label:
	var l := label(text, size, color, 6)
	l.add_theme_font_override("font", Art.font(false))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func panel(bg := PANEL_BG, border := Art.OUTLINE, pad := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 0
	p.add_theme_stylebox_override("panel", sb)
	return p


static func swatch(color: Color, size := 18) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(size, size)
	return r


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Big centred text that pops in, holds, and fades out. Returns the label.
static func banner(parent: Node, text: String, color := Color.WHITE, size := 96, hold := 0.8) -> Label:
	var l := title(text, size, color, 16)
	full_rect(l)
	l.pivot_offset = Vector2(640, 360)
	parent.add_child(l)
	l.pivot_offset = l.get_viewport_rect().size * 0.5
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
	return l


## A player's name tag: colour swatch + name + optional extra text.
static func player_tag(slot: PlayerSlot, extra := "", size := 22) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(swatch(slot.color, int(size * 0.8)))
	var n := label(slot.display_name, size, slot.color.lightened(0.3), 6)
	h.add_child(n)
	if extra != "":
		h.add_child(label(extra, size, Color.WHITE, 6))
	return h
