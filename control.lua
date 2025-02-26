local gui = require("gui")
local damage_lib = require("damage")
---@type EntityPrototypeFilter[]
local vehicle_filters = {{filter="type", type="car"}, {mode="or", filter="type", type="spider-vehicle"}}

local vehicle_inventories = {
	defines.inventory.car_trunk,
	defines.inventory.car_ammo,
	defines.inventory.car_trash,
	defines.inventory.fuel,
}

---@param character LuaEntity
local function no_room(character)
	--TODO Play error sound
	character.player.create_local_flying_text{
		text = "No room in inventory",
		position = character.position
	}
end

---@param character LuaEntity
local function no_space(character, vehicle_name)
	vehicle_name = vehicle_name or "vehicle"
	--TODO Play error sound
	character.player.create_local_flying_text{
		text = "No space for " .. vehicle_name,
		position = character.position
	}
end

---Copy a grid into a other as long as they have the same size
---@param source LuaEquipmentGrid
---@param target LuaEquipmentGrid
local function copy_grid(source, target)
	for x=0, source.width do
		for y=0, source.height do
			local equipment = source.get({x, y})
			if equipment and equipment.position.x == x and equipment.position.y == y then
				target.put{
					name = equipment.name,
					quality = equipment.quality,
					position = {x, y},
				}
			end
		end
	end
end

---@param character LuaEntity
local function pickup_vehicle(character)
	--TODO Save vehicle prototype, fuel and ammo
	local character_inventory = character.get_inventory(defines.inventory.character_main)
	if not character_inventory then return end
	local vehicle = character.vehicle
	if not vehicle then return end
	
	for _, inventory_type in pairs(vehicle_inventories) do
		local inventory = vehicle.get_inventory(inventory_type)
		if not inventory then goto next_inventory end
		for _, content in pairs(inventory.get_contents()) do
			if character_inventory.can_insert(content) then
				local initial_count = content.count
				local inserted = character_inventory.insert(content)
				inventory.remove{
					name = content.name,
					quality = content.quality,
					count = inserted,
				}
				if initial_count ~= inserted then
					no_room(character)
					return
				end
			else
				no_room(character)
				return
			end
		end
		::next_inventory::
	end
	local vehicle_items = vehicle.prototype.items_to_place_this
	if vehicle_items and character_inventory.can_insert(vehicle_items[1]) then
		local item = vehicle_items[1]
		local empty_stack = character_inventory.find_empty_stack({name=item.name, quality=item.quality})
		if not empty_stack then
			no_room(character)
			return
		end
		character_inventory.insert({
			name = item.name,
			quality = item.quality,
			health = vehicle.health / vehicle.max_health
		})
		if empty_stack.valid_for_read and vehicle.grid then
			local grid = empty_stack.create_grid()
			copy_grid(vehicle.grid, grid)
		end
		local position = vehicle.position
		vehicle.destroy()
		character.teleport(position)
		character.player.play_sound{
			path="utility/deconstruct_medium"
		}
	else
		no_room(character)
	end
end

---@param inventory LuaInventory
---@param player_index int
---@return LuaItemStack?
local function select_vehicle(inventory, player_index)
	---@type LuaItemStack?
	local selection = nil
	local selection_priority = -100
	---@type table<string, (int|false)?>
	local favorites = storage.players[player_index].favorites["vehicles"]

	for _, item in pairs(inventory.get_contents()) do
		local prototype = prototypes.item[item.name]
		if prototype.place_result then
			if prototype.place_result.type == "car" or prototype.place_result.type == "spider-vehicle" then
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
	local vehicle_stack = select_vehicle(inventory, character.player.index)
	if not vehicle_stack then return end
	
	if character.driving then pickup_vehicle(character) end --For quick swap

	local prototype = vehicle_stack.item.prototype
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
		no_space(character)
		return
	end
	character.teleport(-20, -20)

	local vehicle = character.surface.create_entity{
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
		character.player.create_local_flying_text{
			position = character.position,
			text = "vehicle creation failed"
		}
		return
end
	--Copy equipment

	if vehicle_stack.item and vehicle_stack.item.grid and vehicle.grid then
		copy_grid(vehicle_stack.item.grid, vehicle.grid)
	end

	vehicle.health = vehicle_stack.health * vehicle.max_health
	inventory.remove({
		name = vehicle_stack.name,
		quality = vehicle_stack.quality,
		count = 1
	})
	vehicle.set_driver(character)
	storage.players[player_index].entered_tick = game.tick

	if math.random() < 0.005 then
		character.player.create_local_flying_text{
			position = character.position,
			text = "CATCH A RIIIIIIIIIIIIDE!",
			time_to_live = 120
		}
	end

	local burner = vehicle.burner
	if burner then
		local fuel_inventory = burner.inventory
		if fuel_inventory then

			for i=1, #fuel_inventory do
				local fuel_stack = select_fuel(inventory, storage.players[player_index].favorites.fuel, burner.fuel_categories)
				if fuel_stack then
					local inserted = fuel_inventory.insert(fuel_stack)
					inventory.remove{
						name= fuel_stack.name,
						quality = fuel_stack.quality,
						count = inserted
					}
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

				local ammo_stack = select_ammo(inventory, storage.players[player_index].favorites.ammo, categories)
				if ammo_stack then
					local inserted = ammo_inventory.insert(ammo_stack)
					inventory.remove{
						name= ammo_stack.name,
						quality = ammo_stack.quality,
						count = inserted
					}
				end
			end
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

script.on_event(defines.events.on_lua_shortcut, function (event)
	if(event.prototype_name == "quick-ride-toggle") then
		gui.toggle_menu(event.player_index)
	end
end)

function validate()
	storage.players = storage.players or {}
	storage.vehicles = {}
	storage.ammo_categories =  {}
	local ammo_categories = storage.ammo_categories
	storage.fuel_categories = {}
	local fuel_categories = storage.fuel_categories

	for id, vehicle in pairs(prototypes.get_entity_filtered(vehicle_filters)) do
		storage.vehicles[id] = vehicle

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
		for item_id, item in pairs(prototypes.get_item_filtered{{filter="fuel-category", ["fuel-category"] = id}}) do
			category.items[item_id] = item
		end
	end

	for _, category in pairs(ammo_categories) do
		category.items = {}
	end
	for id, item in pairs(prototypes.get_item_filtered{{filter="type", type = "ammo"}}) do
		if item.ammo_category and ammo_categories[item.ammo_category.name] then
			ammo_categories[item.ammo_category.name].items[id] = item
		end
	end
	
	for player_index, player in pairs(game.players) do
		storage.players[player_index] = storage.players[player_index] or {}
		storage.players[player_index].entered_tick = storage.players[player_index].entered_tick or 0
		storage.players[player_index].double_tap_delay = player.mod_settings["qr-double-tap-delay"].value * 60
	end

	gui.init()
end

script.on_event(defines.events.on_player_joined_game, function (event)
	local player = game.get_player(event.player_index)
	storage.players[event.player_index] = {
		entered_tick = 0,
		double_tap_delay = player and player.mod_settings["qr-double-tap-delay"].value * 60
	}
	gui.validate_player(event.player_index)
end)

script.on_init(function ()
	validate()
end)

script.on_configuration_changed(function ()
	validate()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function (event)
	local player = game.get_player(event.player_index)
	if not player then return end
	local player_storage = storage.players[event.player_index]
	player_storage.double_tap_delay = player.mod_settings["qr-double-tap-delay"].value * 60
end)

script.on_event(defines.events.on_gui_click, function (event)
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
end)

script.on_event(defines.events.on_gui_closed, function (event)
	if event.element and event.element.name == "quick-ride-main" then
		local player_storage = storage.players[event.player_index]
		if player_storage and player_storage.gui then
			gui.toggle_menu(event.player_index)
		end
	end
end)