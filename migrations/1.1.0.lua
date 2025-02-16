if not storage.players then return end

for _, player_storage in pairs(storage.players) do
	if player_storage.favorites then
		local old_favorites = player_storage.favorites
		local new_favorites = {
			vehicles = {},
			ammo = {},
			fuel = {},
		}

		for list --[[@as string]], value in pairs(old_favorites) do
			if list == "vehicles" then
				new_favorites.vehicles[value] = 1
			else
				local _, _, category = list:find("(%a+)-.*")
				if category then
					new_favorites[category][value] = 1
				end
			end
		end

		player_storage.favorites = new_favorites
	end
end