require("util")
local math2d = require("math2d")

local gui = require("gui")
local damage_lib = require("damage")

---@type EntityPrototypeFilter[]
local vehicle_filters = { { filter = "type", type = "car" }, { mode = "or", filter = "type", type = "spider-vehicle" } }
---@type EntityPrototypeFilter[]
local locomotive_included_filters = table.deepcopy(vehicle_filters)
table.insert(locomotive_included_filters, { mode = "or", filter = "type", type = "locomotive" })

local rail_detect_range = 3.5

local rail_types = {
	"curved-rail-a",
	"elevated-curved-rail-a",
	"curved-rail-b",
	"elevated-curved-rail-b",
	"curved-rail-b",
	"half-diagonal-rail",
	"elevated-half-diagonal-rail",
	"legacy-curved-rail",
	"legacy-straight-rail",
	"rail-ramp",
	"straight-rail",
	"elevated-straight-rail"
}

local vehicle_inventories = {
	defines.inventory.car_trunk,
	defines.inventory.car_ammo,
	defines.inventory.car_trash,
	defines.inventory.fuel,
}

--Adapted from the quality mod
function get_item_localised_name(name)
	local item = prototypes.item[name]
	if not item then return end
	if item.localised_name then
		return item.localised_name
	end
	local prototype
	local type_name = "item"
	if item.place_result then
		prototype = prototypes.entity[item.place_result.name]
		type_name = "entity"
	end
	return prototype and prototype.localised_name or { type_name .. "-name." .. name }
end

---@param character LuaEntity
local function no_space(character, vehicle_name)
	vehicle_name = vehicle_name or "vehicle"
	--TODO Play error sound
	character.player.create_local_flying_text {
		text = { "ui.qr-no-space", get_item_localised_name(vehicle_name) },
		position = character.position
	}
end

---Get the closest rail
---@param character LuaEntity
---@return LuaEntity[]
local function get_close_rail(character)
	return character.surface.find_entities_filtered {
		position = character.position,
		radius = rail_detect_range,
		type = rail_types
	}
end

---@param character LuaEntity
local function pickup_vehicle(character)
	--TODO Save vehicle prototype, fuel and ammo
	local character_inventory = character.get_inventory(defines.inventory.character_main)
	if not character_inventory then return end
	local vehicle = character.vehicle
	if not vehicle or not vehicle.valid then return end

	local position = vehicle.position
	local vehicle_type = vehicle.type
	if character.player.mod_settings["qr-ignore-unhandled-on-exit"].value --[[@as boolean]] then
		if not character.player.mod_settings["qr-handle-trains"].value --[[@as boolean]] and vehicle_type == "locomotive" then
			return
		end

		if storage.players[character.player.index].favorites["vehicles"][vehicle.name] == false then
			return
		end
	end
	vehicle.set_driver(nil)
	--for some reason, probably due to interactions with other mods, exiting the vehicle can make it invalid
	if not vehicle.valid then return end
	local succeded = vehicle.mine { inventory = character_inventory, raise_destroyed = true }
	if succeded then
		if vehicle_type ~= "locomotive" then character.teleport(position) end
	else
		local action = character.player.mod_settings["qr-inventory-full-action"].value
		local text_position = character.position
		if action == "stay-in" then
			text_position = vehicle.position
			vehicle.set_driver(character)
		end
		character.player.create_local_flying_text {
			position = text_position,
			color = { 1, 0, 0 },
			text = "Inventory full"
		}
	end
end

---@param inventory LuaInventory
---@param player_index int
---@param on_rails boolean
---@return LuaItemStack?
local function select_vehicle(inventory, player_index, on_rails)
	---@type LuaItemStack?
	local selection = nil
	local selection_priority = -100
	local locomotive_found = false
	---@type table<string, (int|false)?>
	local favorites = storage.players[player_index].favorites["vehicles"]

	for _, item in pairs(inventory.get_contents()) do
		local prototype = prototypes.item[item.name]
		if prototype.place_result then
			local type = prototype.place_result.type
			if ((type == "car" or type == "spider-vehicle") and not locomotive_found) or (type == "locomotive" and on_rails) then
				if favorites[item.name] == false then goto continue end
				local priority = favorites[item.name] or 0
				if selection then
					local quality_prototype = prototypes.quality[item.quality]
					if selection_priority >= priority and selection.name ~= item.name then goto continue end
					if selection.name == item.name and selection.quality.level >= quality_prototype.level then goto continue end
				end
				selection = inventory.find_item_stack({
					name = item.name,
					quality = item.quality,
					count = item.count
				})
				selection_priority = priority
				if type == "locomotive" then locomotive_found = true end
			end
		end
		::continue::
	end
	return selection
end

---@param inventory LuaInventory
---@param favorites table<ItemID, (int|false)?>
---@param fuel_categories table<data.FuelCategoryID, true>
---@return LuaItemStack?
local function select_fuel(inventory, favorites, fuel_categories)
	---@type LuaItemStack?
	local selection = nil
	local selection_priority = -100

	for _, item in pairs(inventory.get_contents()) do
		local prototype = prototypes.item[item.name]
		if prototype.fuel_category then
			if fuel_categories[prototype.fuel_category] then
				if favorites[item.name] == false then goto continue end
				local priority = favorites[item.name] or 0
				if selection then
					local quality_prototype = prototypes.quality[item.quality]
					if selection_priority > priority and selection.name ~= item.name then goto continue end
					if selection.name == item.name and selection.quality.level >= quality_prototype.level then goto continue end
					if selection_priority == priority and prototype.fuel_value < selection.prototype.fuel_value then goto continue end
				end
				selection = inventory.find_item_stack({
					name = item.name,
					quality = item.quality,
					count = item.count
				})
				selection_priority = priority
			end
		end
		::continue::
	end
	return selection
end

---@param ammo LuaItemPrototype
local function get_ammo_damage(ammo)
	local ammo_type = ammo.get_ammo_type("vehicle")
	if not ammo_type or not ammo_type.action then return 0 end

	local damage = 0
	for _, action in pairs(ammo_type.action) do
		damage = damage + damage_lib.get_action_damage(action)
	end

	return damage
end

---@param inventory LuaInventory
---@param favorites table<ItemID, (int|false)?>
---@param ammo_categories table<data.AmmoCategoryID, true>
---@return LuaItemStack?
local function select_ammo(inventory, favorites, ammo_categories)
	---@type LuaItemStack?
	local selection = nil
	local selection_damage = 0
	local selection_priority = -100

	for _, item in pairs(inventory.get_contents()) do
		local prototype = prototypes.item[item.name]
		if prototype.type == "ammo" then
			if ammo_categories[prototype.ammo_category.name] then
				if favorites[item.name] == false then goto continue end
				local damage = get_ammo_damage(prototype)
				local priority = favorites[item.name] or 0

				if selection then
					local quality_prototype = prototypes.quality[item.quality]
					if selection_priority > priority and selection.name ~= item.name then goto continue end
					if selection.name == item.name and selection.quality.level >= quality_prototype.level then goto continue end
					if selection_priority == priority and selection_damage > damage then goto continue end
				end
				selection = inventory.find_item_stack({
					name = item.name,
					quality = item.quality,
					count = item.count
				})
				selection_damage = damage
				selection_priority = priority
			end
		end
		::continue::
	end
	return selection
end

---@param character LuaEntity
local function place_vehicle(character)
	local player_index = character.player.index
	local inventory = character.get_inventory(defines.inventory.character_main)
	if not inventory then return end
	local player_storage = storage.players[character.player.index]

	local rails = get_close_rail(character)

	-- Ignore rails if player doesn't want to handle trains
	local on_rails = table_size(rails) > 0 and character.player.mod_settings["qr-handle-trains"].value --[[@as boolean]]

	local vehicle_stack = select_vehicle(inventory, character.player.index, on_rails)
	if not vehicle_stack then return end

	if character.driving then pickup_vehicle(character) end --For quick swap

	local prototype = (vehicle_stack.item or vehicle_stack).prototype
	local position = character.position

	character.teleport(20, 20)
	if not character.surface.can_place_entity({
				name = prototype.place_result.name,
				position = position,
				direction = character.direction,
				force = character.force,
				build_check_type = defines.build_check_type.manual
			}) then
		character.teleport(-20, -20)
		no_space(character, prototype.name)
		return
	end

	local vehicle = character.surface.create_entity {
		name = prototype.place_result.name,
		quality = vehicle_stack.quality,
		position = position,
		source = character,
		direction = character.direction,
		force = character.force,
		item = vehicle_stack,
		preserve_ghosts_and_corpses = true,
		raise_built = true,
	}
	if not vehicle then
		character.teleport(-20, -20)
		character.player.create_local_flying_text {
			position = character.position,
			color = { 1, 0, 0 },
			text = "vehicle creation failed"
		}
		return
	end

	vehicle.health = vehicle_stack.health * vehicle.max_health
	inventory.remove({
		name = vehicle_stack.name,
		quality = vehicle_stack.quality,
		count = 1
	})
	vehicle.set_driver(character)
	player_storage.entered_tick = game.tick

	if math.random() < 0.005 then
		character.player.create_local_flying_text {
			position = math2d.position.add(vehicle.position, { 0, -0.6 }),
			text = "CATCH A RIIIIIIIIIIIIDE!",
			time_to_live = 120
		}
	end

	local burner = vehicle.burner
	if burner then
		local fuel_inventory = burner.inventory
		---@type <ItemID, count>
		local fuel_used = {}
		if fuel_inventory then
			for i = 1, #fuel_inventory do
				local fuel_stack = select_fuel(inventory, player_storage.favorites.fuel, burner.fuel_categories)
				if fuel_stack then
					local inserted = fuel_inventory.insert(fuel_stack)
					fuel_used[fuel_stack.name] = (fuel_used[fuel_stack.name] or 0) + inserted
					inventory.remove {
						name = fuel_stack.name,
						quality = fuel_stack.quality,
						count = inserted
					}
				end
			end

			if character.player.mod_settings["qr-show-used-fuel"].value then
				local i = 0
				for item, count in pairs(fuel_used) do
					character.player.create_local_flying_text {
						position = math2d.position.add(vehicle.position, { 0, i * 0.6 }),
						text = count .. " × [item=" .. item .. "] used as fuel",
					}
					i = i + 1
				end
			end
		end
	end

	local guns = vehicle.prototype.guns
	if guns then
		local ammo_inventory = vehicle.get_inventory(defines.inventory.car_ammo)
		if ammo_inventory then
			for _, gun in pairs(guns) do
				---@type table<ItemID, true>
				local categories = {}
				if gun.attack_parameters and gun.attack_parameters.ammo_categories then
					for _, ammo_category in pairs(gun.attack_parameters.ammo_categories) do
						categories[ammo_category] = true
					end
				end

				local ammo_stack = select_ammo(inventory, player_storage.favorites.ammo, categories)
				if ammo_stack then
					local inserted = ammo_inventory.insert(ammo_stack)
					inventory.remove {
						name = ammo_stack.name,
						quality = ammo_stack.quality,
						count = inserted
					}
				end
			end
		end
	end

	if vehicle.type == "locomotive" then
		if character.player.mod_settings["qr-correct-train-direction"].value then
			local train = vehicle.train
			if not train then
				error("Oups! Pas de train")
			end
			local end_rail = train.front_end
			local direction = end_rail.direction
			if end_rail.rail.get_rail_segment_signal(direction, true) then
				if not end_rail.rail.get_rail_segment_signal(direction, false) then
					local opposed_direction = util.oppositedirection(vehicle.direction)
					vehicle.direction = opposed_direction
				end
			end
		end
		if character.player.mod_settings["qr-opens-train-menu"].value then
			character.player.opened = vehicle
		end
	end
end

script.on_event("quick-ride", function(event)
	local player = game.players[event.player_index]
	if not player.character then return end
	local player_storage = storage.players[event.player_index]

	if not player.character.driving or event.tick - player_storage.entered_tick < player_storage.double_tap_delay then
		place_vehicle(player.character)
	else
		pickup_vehicle(player.character)
	end
end)

script.on_event("quick-ride-toggle", function(event)
	gui.toggle_menu(event.player_index)
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
	if (event.prototype_name == "quick-ride-toggle") then
		gui.toggle_menu(event.player_index)
	end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	if event.setting ~= "qr-double-tap-delay" then return end

	local player_storage = storage.players[event.player_index]
	local player = game.get_player(event.player_index)
	if not player then return end

	if event.setting == "qr-double-tap-delay" then
		player_storage.double_tap_delay = player.mod_settings["qr-double-tap-delay"].value * 60
	end
end)

function validate()
	storage.players = storage.players or {}
	storage.vehicles = {}
	storage.locomotives = {}
	storage.ammo_categories = {}
	local ammo_categories = storage.ammo_categories
	storage.fuel_categories = {}
	local fuel_categories = storage.fuel_categories

	for id, vehicle in pairs(prototypes.get_entity_filtered(locomotive_included_filters)) do
		if vehicle.type == "locomotive" then
			storage.locomotives[id] = vehicle
		else
			storage.vehicles[id] = vehicle
		end

		--ammo categories
		if vehicle.guns then
			for _, gun in pairs(vehicle.guns) do
				if gun.attack_parameters and gun.attack_parameters.ammo_categories then
					for _, category in pairs(gun.attack_parameters.ammo_categories) do
						ammo_categories[category] = ammo_categories[category] or {
							vehicles = {}
						}
						ammo_categories[category].vehicles[id] = true
					end
				end
			end
		end
		--fuel
		if vehicle.burner_prototype then
			for category in pairs(vehicle.burner_prototype.fuel_categories) do
				fuel_categories[category] = fuel_categories[category] or {
					vehicles = {}
				}

				fuel_categories[category].vehicles[id] = true
			end
		end
	end

	for id, category in pairs(fuel_categories) do
		category.items = {}
		for item_id, item in pairs(prototypes.get_item_filtered { { filter = "fuel-category", ["fuel-category"] = id } }) do
			category.items[item_id] = item
		end
	end

	for _, category in pairs(ammo_categories) do
		category.items = {}
	end
	for id, item in pairs(prototypes.get_item_filtered { { filter = "type", type = "ammo" } }) do
		if item.ammo_category and ammo_categories[item.ammo_category.name] then
			ammo_categories[item.ammo_category.name].items[id] = item
		end
	end

	for player_index, player in pairs(game.players) do
		storage.players[player_index] = storage.players[player_index] or {}
		local player_storage = storage.players[player_index]
		player_storage.entered_tick = player_storage.entered_tick or 0
		player_storage.double_tap_delay = player.mod_settings["qr-double-tap-delay"].value * 60
	end

	gui.init()
end

script.on_event(defines.events.on_player_joined_game, function(event)
	local player = game.get_player(event.player_index)
	storage.players[event.player_index] = {
		entered_tick = 0,
		double_tap_delay = player and player.mod_settings["qr-double-tap-delay"].value * 60,
	}
	gui.validate_player(event.player_index)
end)

script.on_init(function()
	validate()
end)

script.on_configuration_changed(function()
	validate()
end)

script.on_event(defines.events.on_gui_click, function(event)
	gui.on_gui_click(event)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
	gui.on_gui_checked_state_changed(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
	if event.element and event.element.name == "quick-ride-main" then
		local player_storage = storage.players[event.player_index]
		if player_storage and player_storage.gui then
			gui.toggle_menu(event.player_index)
		end
	end
end)
