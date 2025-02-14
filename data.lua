data:extend{
  {
    type = "custom-input",
    name = "quick-ride",
    key_sequence = "SHIFT + V"
  },  
  {
    type = "custom-input",
    name = "quick-ride-toggle",
    key_sequence = "ALT + V"
  },
  {
    type = "shortcut",
    name = "quick-ride-toggle",
    action = "lua",
    associated_control_input = "quick-ride-toggle",
    icon = "__base__/graphics/icons/car.png",
    small_icon = "__base__/graphics/icons/car.png"
  },
}

--Style
local styles = data.raw["gui-style"]["default"]

if not styles.titlebar_drag_handle then
  -- From https://man.sr.ht/~raiguard/factorio-gui-style-guide/#titlebar
  styles.titlebar_drag_handle = {
    type = "empty_widget_style",
    parent = "draggable_space",
    height = 24,
    horizontally_stretchable = "on",
    right_margin = 4,
  }
end

styles.qr_item_row =
{
  type = "frame_style",
  parent = "slot_button_deep_frame",
  minimal_height = slot_size,
  minimal_width = slot_size * 5,
  vertically_stretchable = "on",
  horizontally_stretchable = "on",
  top_margin = 2,
  left_margin = 8,
  right_margin = 8,
  bottom_margin = 4
}

styles.qr_subheader =
{
  type = "label_style",
  parent = "subheader_caption_label",
  top_margin = 4,
  bottom_margin = 4
}

styles.qr_subtitle =
{
  type = "label_style",
  parent = "bold_label",
  top_margin = 4,
  bottom_margin = 2,
  left_margin = 8,
}

styles.qr_separator =
{
  type = "line_style",
  top_margin = 4,
  bottom_margin = 4
}
