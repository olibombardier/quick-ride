local gui = require("gui")
local damage_lib = require("damage")

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
		character_inventory.insert({
			name = item.name,
			quality = item.quality,
			health = vehicle.health / vehicle.max_health,
		})
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
	---@type string?
	local favorite = storage.players[player_index].favorites["vehicles"]

	for _, item in pairs(inventory.get_contents()) do
		local prototype = prototypes.item[item.name]
		if prototype.place_result then
			if prototype.place_result.type == "car" then
				if selection then
					local quality_prototype = prototypes.quality[item.quality]
					if selection.name == favorite and item.name ~= favorite then goto continue end
					if selection.name == item.name and selection.quality.level > quality_prototype.level then goto continue end
					if item.name ~= favorite then goto continue end
				end
				selection = inventory.find_item_stack({
					name = item.name,
					quality = item.quality,
					count = item.count
				}) --[[@as LuaItemStack]]
			end
		end
		::continue::
	end
	return selection
end

---@param inventory LuaInventory
---@param favorite string?
---@param fuel_categories table<data.FuelCategoryID, true>
---@return LuaItemStack?
local function select_fuel(inventory, favorite, fuel_categories)
	---@type LuaItemStack?
	local selection = nil

	for _, item in pairs(inventory.get_contents()) do
		local prototype = prototypes.item[item.name]
		if prototype.fuel_category then
			if fuel_categories[prototype.fuel_category] then
				if selection then
					local quality_prototype = prototypes.quality[item.quality]
					if selection.name == favorite and item.name ~= favorite then goto continue end
					if selection.name == item.name and selection.quality.level > quality_prototype.level then goto continue end
					if prototype.fuel_value < selection.prototype.fuel_value then goto continue end
				end
				selection = inventory.find_item_stack({
					name = item.name,
					quality = item.quality,
					count = item.count
				}) --[[@as LuaItemStack]]
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
---@param favorite ItemID?
---@param ammo_categories table<data.AmmoCategoryID, true>
---@return LuaItemStack?
local function select_ammo(inventory, favorite, ammo_categories)
	---@type LuaItemStack?
	local selection = nil
	local selection_damage = 0

	for _, item in pairs(inventory.get_contents()) do
		local prototype = prototypes.item[item.name]
		if prototype.type == "ammo" then
			if ammo_categories[prototype.ammo_category.name] then
				local damage = get_ammo_damage(prototype)
				if selection then
					local quality_prototype = prototypes.quality[item.quality]
					if selection.name == favorite and item.name ~= favorite then goto continue end
					if selection.name == item.name and selection.quality.level > quality_prototype.level then goto continue end
					if selection_damage > damage then goto continue end
				end
				selection = inventory.find_item_stack({
					name = item.name,
					quality = item.quality,
					count = item.count
				}) --[[@as LuaItemStack]]
				selection_damage = damage
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
		direction = character.direction,
		force = character.force,
		item = vehicle_stack,
		preserve_ghosts_and_corpses = true
	}
	if not vehicle then
		character.player.create_local_flying_text{
			position = character.position,
			text = "vehicle creation failed"
	}
	else
		vehicle.health = vehicle_stack.health * vehicle.max_health
		inventory.remove({
			name = vehicle_stack.name,
			quality = vehicle_stack.quality,
			count = 1
		})
		vehicle.set_driver(character)

		local burner = vehicle.burner
		if burner then
			local fuel_inventory = burner.inventory
			if fuel_inventory then
				---@type ItemID?
				local favorite = nil
				for fuel_category in pairs(burner.fuel_categories) do
					favorite = storage.players[player_index].favorites["fuel-" .. fuel_category]
					if favorite then break end
				end

				for i=1, #fuel_inventory do
					local fuel_stack = select_fuel(inventory, favorite, burner.fuel_categories)
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
					---@type ItemID?
					local favorite = nil
					local categories = {}
					if gun.attack_parameters and gun.attack_parameters.ammo_categories then
						for _, ammo_category in pairs(gun.attack_parameters.ammo_categories) do
							categories[ammo_category] = true
							favorite = storage.players[player_index].favorites["ammo-" .. ammo_category]
							if favorite then break end
						end
					end

					local ammo_stack = select_ammo(inventory, favorite, categories)
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
end

script.on_event("quick-ride", function(event)
	local player = game.players[event.player_index]
	if not player.character then return end
	
	if player.character.driving then
		pickup_vehicle(player.character)
	else
		place_vehicle(player.character)
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
	storage.vehicles = storage.vehicles or {}
	storage.ammo_categories =  {}
	local ammo_categories = storage.ammo_categories
	storage.fuel_categories = {}
	local fuel_categories = storage.fuel_categories

	for id, vehicle in pairs(prototypes.get_entity_filtered{{filter="type", type="car"}}) do
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
		for item_id in pairs(prototypes.get_item_filtered{{filter="fuel-category", ["fuel-category"] = id}}) do
			category.items[item_id] = true
		end
	end

	for _, category in pairs(ammo_categories) do
		category.items = {}
	end
	for id, item in pairs(prototypes.get_item_filtered{{filter="type", type = "ammo"}}) do
		if item.ammo_category and ammo_categories[item.ammo_category.name] then
			ammo_categories[item.ammo_category.name].items[id] = true
		end
	end
	
	for player_index in pairs(game.players) do
		storage.players[player_index] = storage.players[player_index] or {}
	end

	gui.init()
end

script.on_event(defines.events.on_player_joined_game, function (event)
	storage.players[event.player_index] = {}
	gui.validate_player(event.player_index)
end)

script.on_init(function ()
	validate()
end)

script.on_configuration_changed(function ()
	validate()
end)

script.on_event(defines.events.on_gui_click, function (event)
	local element = event.element
	if element.name == "qr-close" then
		gui.toggle_menu(event.player_index)
	elseif element.tags.action == "qr-selection" then
		for _, child in pairs(element.parent.children) do
			child.toggled = child == element
		end
		storage.players[event.player_index].favorites[element.tags.list] = element.tags.choice
	end
end)