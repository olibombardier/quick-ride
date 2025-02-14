local lib = {}

---@param delivery TriggerDelivery
function lib.get_projectile_trigger_delivery_damage(delivery)
	local projectile = prototypes.entity[delivery.projectile]
	return lib.get_action_damage(projectile.attack_result)
end

---@param delivery TriggerDelivery
function lib.get_instant_trigger_delivery_damage(delivery)
	local damage = 0
	if delivery.target_effects then
		for _, effect in pairs(delivery.target_effects) do
			if effect.damage then damage = damage + effect.damage.amount end
		end
	end
	if delivery.source_effects then
		for _, effect in pairs(delivery.source_effects) do
			if effect.projectile then damage = damage + effect.damage.amount end
		end
	end
	return damage
end

---@param delivery TriggerDelivery
function lib.get_delivery_damage(delivery)
	local f = function () return 0 end

	if delivery.type == "instant" then f = lib.get_instant_trigger_delivery_damage end
	if delivery.type == "projectile" then f = lib.get_projectile_trigger_delivery_damage end


	return f(delivery)
end

---@param action TriggerItem
function lib.get_action_damage(action)
	local damage = 0
	if action.action_delivery then
		if type(action.action_delivery) == "table" then
			for _, delivery in pairs(action.action_delivery) do
				damage = damage + lib.get_delivery_damage(delivery)
			end
		else
			damage = damage + lib.get_delivery_damage(action.action_delivery)
		end
	end

	return damage
end

return lib