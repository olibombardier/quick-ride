local mod_gui = require("mod-gui")

local gui = {}

gui.column_count = 10

local vehicle_types = {
	car = true,
	["spider-vehicle"] = true,
	locomotive = true
}

function gui.init()
	-- Make storage variables
	-- Create gui for players
	for _, player in pairs(game.players) do
		gui.validate_player(player)
	end
end

function gui.validate_player(player)
	if type(player) ~= "userdata" then
		player = game.get_player(player)
		if not player then return end
	end
	--[[@cast player LuaPlayer]]
	local player_storage = storage.players[player.index]

	player_storage.favorites = player_storage.favorites or {
		vehicles = {},
		fuel = {},
		ammo = {},
	}

	if player_storage.gui then
		player_storage.gui.main_frame.destroy()
		gui.make_gui(player)
	end
end

function gui.toggle_menu(player_index)
	local existing_gui = storage.players[player_index].gui
	if existing_gui then
		existing_gui.main_frame.destroy()
		storage.players[player_index].gui = nil
	else
		gui.make_gui(game.get_player(player_index))
	end
end

---@param parent LuaGuiElement
---@param item_list table<string, LuaPrototypeBase>
---@param list_name string
---@param player_storage any
---@param item_type "entity"|"item"
local function make_section(parent, item_list, list_name, player_storage, item_type)
	local column_index = 0

	for id, prototype in pairs(item_list) do
		local value = player_storage.favorites[list_name][id]
		local blacklisted = value == false

		local sprite = item_type .. "." .. id
		if vehicle_types[prototype.type] and prototype.items_to_place_this and table_size(prototype.items_to_place_this) == 1 then
			sprite = "item." .. prototype.items_to_place_this[1].name
		end

		---@type LuaGuiElement.add_param
		local params = {
			type = "sprite-button",
			name = "qr-selection-" .. id,
			tooltip = prototype.localised_name,
			sprite = sprite,
			toggled = value == 1,
			tags = {
				action = "qr-selection",
				list = list_name,
				choice = id,
			}
		}

		local button = parent.add(params)
		if blacklisted then
			
			button.add{
				type = "empty-widget",
				style = "qr_blacklist_overlay",
				name = "x_icon"
			}
		end
		column_index = column_index +1
	end

	while column_index % gui.column_count ~= 0 do
		parent.add{type = "empty-widget"}
		column_index = column_index + 1
	end
end

---@param button LuaGuiElement
function gui.update_button_style(button, value)
	if value == 1 then
		button.toggled = true
		if button.x_icon then button.x_icon.destroy() end
	elseif value == false then
		button.toggled = false
		if not button.x_icon then
			button.add{
				type = "empty-widget",
				style = "qr_blacklist_overlay",
				name = "x_icon"
			}
		end
	else
		button.toggled = false
		if button.x_icon then button.x_icon.destroy() end
	end
end

---@param parent LuaGuiElement
---@param content string|LocalisedString
local function make_subheader(parent, content)
	parent.add{
		type = "label",
		caption = content,
		style = "qr_subheader"
	}
end

---@param parent LuaGuiElement
---@return LuaGuiElement
local function make_section_frame(parent)
	local pane = parent.add{
		type = "scroll-pane",
		direction = "vertical",
		style = "qr_item_pane"
	}

	return pane.add{
		type = "table",
		column_count = gui.column_count,
		style = "filter_slot_table"
	}
end

function gui.get_view_button_names(row_view)
	local base_name = "qr-row-view"
	if row_view then base_name = "qr-list-view" end
	return {
		normal = base_name,
		dark = base_name .. "-black"
	}
end

---comment
---@param main_frame LuaGuiElement
---@param player_storage any
function gui.make_gui_content(player_index)
	local player_storage = storage.players[player_index]

	---@type LuaGuiElement
	local main_frame = player_storage.gui.main_frame
	---@type LuaGuiElement
	local main_flow = main_frame.main_flow
	local top = main_frame.location.y

	if main_flow.content then main_flow.content.destroy() end

	---@type LuaGuiElement
	local content_frame
	local info_frame
	if player_storage.row_view then
		content_frame = main_flow.add{
			type = "flow",
			name = "content",
			direction = "vertical"
		}
		info_frame = content_frame.add{
			type = "frame",
			style = "qr_shallow_frame",
			direction = "vertical"
		}
	else
		content_frame = main_flow.add{
			type = "frame",
			name = "content",
			style = "qr_shallow_frame",
			direction = "vertical"
		}
		info_frame = content_frame
	end
	
	info_frame.add{
		type = "label",
		caption = "Left-click to set as a favorite item."
	}
	info_frame.add{
		type = "label",
		caption = "Right-click to blacklist an item."
	}
	info_frame.add{
		type = "label",
		caption = "[img=info] Double tapping the Quick ride shortcut will swap to the next vehicle."
	}
	
	---@type LuaGuiElement
	local row = nil
	if player_storage.row_view then
		row = content_frame.add{
			type = "flow",
			direction = "horizontal"
		}
		content_frame = row.add{
			type = "frame",
			style = "qr_shallow_frame",
			direction = "vertical"
		}
	end

	make_subheader(content_frame, "Vehicle")
	local vehicle_frame = make_section_frame(content_frame)
	make_section(vehicle_frame, storage.vehicles, "vehicles", player_storage, "entity")
	make_section(vehicle_frame, storage.locomotives, "vehicles", player_storage, "entity")

	if player_storage.row_view then
		content_frame = row.add{
			type = "frame",
			style = "qr_shallow_frame",
			direction = "vertical"
		}
	else
	content_frame.add{
		type = "line",
		direction = "horizontal",
		style = "qr_separator",
	}
	end

	make_subheader(content_frame, "Fuel")
	local fuel_frame = make_section_frame(content_frame)
	for _, category in pairs(storage.fuel_categories) do
		make_section(fuel_frame, category.items, "fuel", player_storage, "item")
	end


	if player_storage.row_view then
		content_frame = row.add{
			type = "frame",
			style = "qr_shallow_frame",
			direction = "vertical"
		}
	else
		content_frame.add{
			type = "line",
			direction = "horizontal",
			style = "qr_separator",
		}
	end

	make_subheader(content_frame, "Ammo")
	local ammo_frame = make_section_frame(content_frame)
	for _, category in pairs(storage.ammo_categories) do
		make_section(ammo_frame, category.items, "ammo", player_storage, "item")
	end

	main_frame.location.top = top
end

---Create the gui for a player
---@param player LuaPlayer
function gui.make_gui(player)
	local player_storage = storage.players[player.index]
	local main_frame = player.gui.screen.add{
		type = "frame",
		name = "quick-ride-main",
	}
	main_frame.auto_center = true
	
	local v_flow = main_frame.add{
		type = "flow",
		name = "main_flow",
		direction = "vertical"
	}

	---@type LuaGuiElement
	local header = v_flow.add{
		type = "flow",
		caption = "Header",
		style = "frame_header_flow"
	}
	header.drag_target = main_frame
	header.style.horizontal_spacing = 8

	header.add{
		type = "label",
		caption = "Quick ride",
		style = "frame_title",
		ignored_by_interaction = true,
	}

	---@type LuaGuiElement
	header.add{
		type="empty-widget",
		style="titlebar_drag_handle",
		ignored_by_interaction = true
	}

	local sprite_names = gui.get_view_button_names(player_storage.row_view)
	header.add{
		type = "sprite-button",
		name = "qr-swap-view",
		sprite = sprite_names.normal,
		hovered_sprite = sprite_names.dark,
		clicked_sprite = sprite_names.normal,
		style = "frame_action_button",
	}

	header.add{
		type = "sprite-button",
		name = "qr-close",
		sprite = "utility/close",
		hovered_sprite = "utility/close_black",
		clicked_sprite = "utility/close",
		style = "frame_action_button",
	}

	player_storage.gui = {
		main_frame = main_frame
	}
	player.opened = main_frame

	gui.make_gui_content(player.index)
end


---@param event EventData.on_gui_click
function gui.on_gui_click(event)
	local element = event.element
	if element.name == "qr-close" then
		gui.toggle_menu(event.player_index)

	elseif element.tags.action == "qr-selection" then
		local list = storage.players[event.player_index].favorites[element.tags.list]
		local old_value = list[element.tags.choice]
		---@type any
		local new_value = 1
		if event.button == defines.mouse_button_type.right then new_value = false end
		if new_value == old_value then new_value = nil end

		list[element.tags.choice] = new_value
		gui.update_button_style(event.element, new_value)

	elseif element.name == "qr-swap-view" then
		storage.players[event.player_index].row_view = not storage.players[event.player_index].row_view
		gui.make_gui_content(event.player_index)
		local sprite_names = gui.get_view_button_names(storage.players[event.player_index].row_view)
		event.element.sprite = sprite_names.normal
		event.element.hovered_sprite = sprite_names.dark
		event.element.clicked_sprite = sprite_names.normal
	end
end

---@param event EventData.on_gui_checked_state_changed
function gui.on_gui_checked_state_changed(event)
	--local element = event.element
	--local player_storage = storage.players[event.player_index]
	--if element.name == "qr-handle-train" then
	--	player_storage.handle_trains = event.element.state
	--elseif element.name == "qr-auto-train-ui" then
	--	player_storage.opens_train_menu = event.element.state
	--end
end

return gui