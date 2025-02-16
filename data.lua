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

  {
    type = "sprite",
    name = "qr-list-view",
    filename = "__quick-ride__/graphics/icons/list-view.png",
    size = 16,
  },
  {
    type = "sprite",
    name = "qr-row-view",
    filename = "__quick-ride__/graphics/icons/row-view.png",
    size = 16,
  },
  {
    type = "sprite",
    name = "qr-list-view-black",
    filename = "__quick-ride__/graphics/icons/list-view-black.png",
    size = 16,
  },
  {
    type = "sprite",
    name = "qr-row-view-black",
    filename = "__quick-ride__/graphics/icons/row-view-black.png",
    size = 16,
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

styles.qr_shallow_frame =
{
  type = "frame_style",
  parent = "inside_shallow_frame",
  padding = 8,
  vertically_stretchable = "on",
}

styles.qr_item_pane =
{
  type = "scroll_pane_style",
  parent = "deep_slots_scroll_pane",
  maximal_height = slot_size * 12,
  top_margin = 2,
  left_margin = 8,
  right_margin = 8,
  bottom_margin = 4,
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
  bottom_margin = 4,
  left_margin = 8,
  right_margin = 8,
}

styles.qr_blacklist_overlay =
{
  type = "empty_widget_style",
  graphical_set = {
    filename = "__core__/graphics/rail-path-not-possible.png",
    size = {64, 64}
  },
  size = {slot_size - 10, slot_size - 10},
  margin = 10,
}