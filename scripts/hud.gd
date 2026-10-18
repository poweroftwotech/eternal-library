extends CanvasLayer
signal choice_selected(action: String)
var zone_label: Label
var prompt_label: Label
var prompt_panel: PanelContainer
var nourishment_bar: ProgressBar
var warmth_bar: ProgressBar
var counts: Array = []
var toast: Label
var toast_time: float = 0
var modal: PanelContainer
var modal_title: Label
var modal_text: RichTextLabel
var modal_buttons: VBoxContainer
var veil: ColorRect
var options: Array = []
var modal_open: bool = false
var dot: Label
var theme = Theme.new()

var pixel_font: bool = false

## VT323 is drawn on an 8 px grid and runs smaller than Consolas: scale by
## 1.3 and snap to multiples of 8 so every glyph pixel stays crisp.
func px_size(size: int) -> int:
	if not pixel_font:
		return size
	return maxi(16,int(size*1.3/8.0+.5)*8)

func _ready() -> void:
	theme.default_font_size = 18
	# Crisp monospace without antialiasing reads as a pixel UI. Swap in an OFL
	# pixel font file (e.g. VT323) at assets/fonts/ui.ttf to override.
	if ResourceLoader.exists("res://assets/fonts/ui.ttf"):
		theme.default_font = load("res://assets/fonts/ui.ttf")
		pixel_font = true
		theme.default_font_size = px_size(18)
	else:
		var font = SystemFont.new()
		font.font_names = PackedStringArray(["Consolas","Cascadia Mono","Lucida Console","DejaVu Sans Mono","Liberation Mono","monospace"])
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NORMAL
		theme.default_font = font
	theme.set_color("font_color","Label",Color("e6dcc3"))
	theme.set_color("default_color","RichTextLabel",Color("ddd8c7"))
	var style = panel_style(Color("17262b"),Color("7c724f"),10)
	var hover = panel_style(Color("294042"),Color("c8ac70"),10)
	theme.set_stylebox("normal","Button",style)
	theme.set_stylebox("hover","Button",hover)
	theme.set_stylebox("pressed","Button",hover)
	theme.set_stylebox("focus","Button",hover)
	theme.set_color("font_color","Button",Color("e6dcc3"))
	theme.set_color("font_disabled_color","Button",Color("797e76"))
	var control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.theme = theme
	add_child(control)
	# v0.11 concept HUD: monospace caps, hairline rules with diamond terminals,
	# numbered slots, plus-shaped crosshair and an [E] prompt beside it.
	var header_margin = MarginContainer.new()
	header_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	header_margin.add_theme_constant_override("margin_left",26)
	header_margin.add_theme_constant_override("margin_top",18)
	header_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(header_margin)
	var header = VBoxContainer.new()
	header.add_theme_constant_override("separation",2)
	header_margin.add_child(header)
	zone_label = label("THE READING GARDEN",20)
	header.add_child(zone_label)
	header.add_child(label("STRATUM I",13))
	header.add_child(Rule.new(Vector2(210,10)))
	dot = label("+",22)
	dot.modulate = Color(1,1,1,.8)
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.offset_left = -12
	dot.offset_right = 12
	dot.offset_top = -14
	dot.offset_bottom = 14
	control.add_child(dot)
	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_panel.offset_left = -40
	prompt_panel.offset_right = 160
	prompt_panel.offset_top = 52
	prompt_panel.offset_bottom = 82
	prompt_panel.add_theme_stylebox_override("panel",panel_style(Color(0.03,.035,.035,.72),Color(0,0,0,0),6))
	prompt_label = label("",17)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	prompt_panel.add_child(prompt_label)
	control.add_child(prompt_panel)
	prompt_panel.visible = false
	var status = VBoxContainer.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.offset_left = 26
	status.offset_right = 340
	status.offset_top = -104
	status.offset_bottom = -22
	status.add_theme_constant_override("separation",10)
	control.add_child(status)
	nourishment_bar = condition(status,"NOURISHMENT",Color("e2c587"))
	warmth_bar = condition(status,"WARMTH",Color("5fb3b0"))
	status.add_child(Rule.new(Vector2(290,10)))
	var slots = HBoxContainer.new()
	slots.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	slots.offset_left = -160
	slots.offset_right = 160
	slots.offset_top = -112
	slots.offset_bottom = -18
	slots.add_theme_constant_override("separation",12)
	control.add_child(slots)
	for i in range(4):
		var stack = VBoxContainer.new()
		stack.custom_minimum_size.x = 68
		stack.add_theme_constant_override("separation",4)
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(68,64)
		var slot_style = panel_style(Color(.02,.03,.03,.82),Color("b89a62"),4)
		slot_style.set_border_width_all(2)
		slot.add_theme_stylebox_override("panel",slot_style)
		var icon = TextureRect.new()
		var icon_name: String = ["mushroom","root","herb","journal"][i]
		# Pixel-art icons (tools/pixel_icons.gd) at 3x, SVG fallback.
		if ResourceLoader.exists("res://assets/ui/icon_%s.png" % icon_name):
			icon.texture = load("res://assets/ui/icon_%s.png" % icon_name)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		else:
			icon.texture = load("res://assets/ui_%s.svg" % icon_name)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(52,48)
		slot.add_child(icon)
		var text = label("0" if i < 3 else "",13)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		slot.add_child(text)
		stack.add_child(slot)
		var number = label("— %d —" % (i+1),13)
		number.modulate = Color("c9b78d")
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(number)
		counts.append(text)
		slots.add_child(stack)
	var help_text = label("E interact   ·   J notes   ·   Esc menu",12)
	help_text.modulate.a = .65
	help_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	help_text.offset_left = -290
	help_text.offset_right = -28
	help_text.offset_top = -40
	help_text.offset_bottom = -20
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	control.add_child(help_text)
	toast = label("",16)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -500
	toast.offset_right = 500
	toast.offset_top = 103
	toast.offset_bottom = 141
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_child(toast)
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(.015,.022,.026,.57)
	veil.visible = false
	control.add_child(veil)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -310
	modal.offset_right = 310
	modal.offset_top = -250
	modal.offset_bottom = 250
	modal.add_theme_stylebox_override("panel",panel_style(Color("111f25"),Color("ab9464"),26))
	modal.visible = false
	control.add_child(modal)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	var stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",17)
	scroll.add_child(stack)
	modal_title = label("",27)
	modal_title.modulate = Color("dfbd7b")
	stack.add_child(modal_title)
	stack.add_child(HSeparator.new())
	modal_text = RichTextLabel.new()
	modal_text.bbcode_enabled = true
	modal_text.fit_content = true
	modal_text.scroll_active = false
	modal_text.custom_minimum_size.y = 85
	stack.add_child(modal_text)
	modal_buttons = VBoxContainer.new()
	modal_buttons.add_theme_constant_override("separation",9)
	stack.add_child(modal_buttons)

func panel_style(background: Color, border: Color, margin: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(margin)
	return style

func label(text: String, font_size: int) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",px_size(font_size))
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func condition(parent: Control, title: String, color: Color) -> ProgressBar:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var text = label(title,13)
	text.custom_minimum_size.x = 118
	row.add_child(text)
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(170,9)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background",panel_style(Color(.04,.05,.05,.8),Color("8c7c56"),1))
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill",fill)
	row.add_child(bar)
	row.add_child(Rule.new(Vector2(14,9),false))
	return bar

func update_values(inventory: Dictionary, nourishment: float, warmth: float) -> void:
	nourishment_bar.value = nourishment
	warmth_bar.value = warmth
	for i in range(3):
		counts[i].text = str(inventory[["mushroom","root","herb"][i]])

func set_prompt(text: String) -> void:
	prompt_panel.visible = not text.is_empty() and not modal_open
	prompt_label.text = "[E] " + text

func notify(text: String) -> void:
	toast.text = text
	toast_time = 5.0

func open(title: String, text: String, choices: Array) -> void:
	modal_title.text = title
	modal_text.text = text
	options = choices
	for child in modal_buttons.get_children():
		modal_buttons.remove_child(child)
		child.queue_free()
	for i in range(choices.size()):
		var button = Button.new()
		button.text = "%d  %s" % [i+1,choices[i].text]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = choices[i].get("disabled",false)
		button.pressed.connect(select.bind(i))
		modal_buttons.add_child(button)
	modal_open = true
	modal.visible = true
	veil.visible = true
	dot.visible = false
	prompt_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for button in modal_buttons.get_children():
		if not button.disabled:
			button.grab_focus()
			break

func close() -> void:
	modal_open = false
	modal.visible = false
	veil.visible = false
	dot.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func select(index: int) -> void:
	if index >= 0 and index < options.size() and not options[index].get("disabled",false):
		choice_selected.emit(options[index].action)

func _process(delta: float) -> void:
	toast_time = maxf(0,toast_time-delta)
	toast.visible = toast_time > 0

func _unhandled_input(event: InputEvent) -> void:
	if modal_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			select(event.keycode-KEY_1)
			get_viewport().set_input_as_handled()


## Hairline with diamond terminals (concept HUD ornament).
class Rule extends Control:
	var line: bool = true
	func _init(min_size: Vector2, draw_line_too: bool = true) -> void:
		custom_minimum_size = min_size
		line = draw_line_too
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var color = Color("b9a679")
		var y: float = size.y*.5
		if line:
			draw_line(Vector2(4,y),Vector2(size.x-4,y),color,1.0)
			diamond(Vector2(3,y),2.5,color)
			diamond(Vector2(size.x*.82,y),3.0,color)
		else:
			diamond(Vector2(size.x*.5,y),3.5,color)
	func diamond(c: Vector2, r: float, color: Color) -> void:
		var points = PackedVector2Array([c+Vector2(0,-r),c+Vector2(r,0),c+Vector2(0,r),c+Vector2(-r,0)])
		draw_polyline(points+PackedVector2Array([points[0]]),color,1.0)
