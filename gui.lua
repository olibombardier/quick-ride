local mod_gui = require("mod-gui")

local gui = {}

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

	player_storage.favorites = player_storage.favorites or {}

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
---@param item_list table<string, true>
---@param list_name string
---@param player_storage any
---@param item_type "entity"|"item"
---@param category string?
---@param subtitles boolean?
local function make_section(parent, item_list, list_name, player_storage, item_type, category, subtitles)
	if table_size(item_list) <= 1 then return end

	if subtitles then
		parent.add{
			type = "label",
			caption = {category .. "-category-name." .. list_name},
			style = "qr_subtitle"
		}
	end
	local item_frame = parent.add{
		type = "frame",
		direction = "horizontal",
		style = "qr_item_row",
	}

	local list_tag = list_name
	if category then list_tag = category .. "-" .. list_name end
	for id in pairs(item_list) do
		local selected = false
		if player_storage.favorites[list_tag] and player_storage.favorites[list_tag] == id then
			selected = true
		end
		item_frame.add{
			type = "sprite-button",
			name = "qr-selection-" .. id,
			sprite = item_type .. "." .. id,
			toggled = selected,
			tags = {
				action = "qr-selection",
				list = list_tag,
				choice = id,
			}
		}
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

function gui.make_gui(player)
	local player_storage = storage.players[player.index]
	local main_frame = player.gui.screen.add{
		type = "frame",
		name = "quick-ride-main",
	}
	main_frame.auto_center = true
	
	local v_flow = main_frame.add{
		type = "flow",
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
	local drag_handle = header.add{
		type="empty-widget",
		style="titlebar_drag_handle",
		ignored_by_interaction = true
	}

	header.add{
		type = "sprite-button",
		name = "qr-close",
		sprite = "utility/close",
		hovered_sprite = "utility/close_black",
		clicked_sprite = "utility/close",
		style = "frame_action_button",
	}

	---@type LuaGuiElement
	local content_frame = v_flow.add{
		type = "frame",
		style = "inside_shallow_frame",
		direction = "vertical"
	}
	
	make_subheader(content_frame, "Vehicle")
	make_section(content_frame, storage.vehicles, "vehicles", player_storage, "entity")

	content_frame.add{
		type = "line",
		direction = "horizontal",
		style = "qr_separator",
	}

	make_subheader(content_frame, "Fuel")
	for fuel_category, category in pairs(storage.fuel_categories) do
		make_section(content_frame, category.items, fuel_category, player_storage, "item", "fuel", table_size(storage.fuel_categories) > 1)
	end

	content_frame.add{
		type = "line",
		direction = "horizontal",
		style = "qr_separator",
	}

	make_subheader(content_frame, "Ammo")
	for ammo_category, category in pairs(storage.ammo_categories) do
		make_section(content_frame, category.items, ammo_category, player_storage, "item", "ammo", table_size(storage.ammo_categories) > 1)
	end

	player_storage.gui = {
	main_frame = main_frame
	}
end

return gui