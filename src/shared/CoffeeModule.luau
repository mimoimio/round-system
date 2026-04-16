local CoffeeConfigArray = require(game.ReplicatedStorage.Shared.Configs.CoffeeConfig)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoffeeModule = {}
export type CoffeeConfigType = {
	Id: string,
	DisplayName: string,
	Price: number?,
	Ingredients: { string }?,
	RecipePath: { string }?, -- sorted at config initialization
	Instruction: string?, -- Readable
	Image: string?,
}

-- Build lookup by Id and track config order for ingredient priority
local CoffeeConfig: { [string]: CoffeeConfigType } = {}
local ingredientPriority: { [string]: number } = {} -- lower = earlier in config = removed last

for index, config in ipairs(CoffeeConfigArray) do
	CoffeeConfig[config.Id] = config
	ingredientPriority[config.Id] = index
end

function CoffeeModule.GetId(Ingredients: { string }): string
	-- Sort ingredients by alphabet and concatenate
	local sorted = table.clone(Ingredients)
	table.sort(sorted)
	return table.concat(sorted)
end

-- Initialize lookup table by assigning each config's resulting ingredients GetId to the config
local lookupTable: { [string]: CoffeeConfigType } = {}

for _, config in ipairs(CoffeeConfigArray) do
	if not config.Ingredients then
		continue
	end
	local id = CoffeeModule.GetId(config.Ingredients)
	lookupTable[id] = config
end

-- Compute Instructions: recursively trace back to a single base ingredient,
-- then reverse to show the step-by-step ingredients to add.
-- Ingredients later in config array are removed first (higher priority number).

local function getIngredientDisplayName(id: string): string
	local cfg = CoffeeConfig[id]
	return cfg and cfg.DisplayName or id
end

-- Sort ingredients by removal priority: higher index in config = removed first
local function sortByRemovalPriority(ingredients: { string }): { string }
	local sorted = table.clone(ingredients)
	table.sort(sorted, function(a, b)
		local pa = ingredientPriority[a] or 9999
		local pb = ingredientPriority[b] or 9999
		return pa > pb -- higher priority number = try to remove first
	end)
	return sorted
end

-- Recursively find a path of ingredient IDs to add, starting from a base ingredient
local function findInstructionPathIds(ingredients: { string }): { string }?
	-- Base case: single ingredient is the starting point
	if #ingredients == 1 then
		return { ingredients[1] }
	end

	-- Sort by removal priority (later in config = removed first)
	local sortedIngredients = sortByRemovalPriority(ingredients)

	-- Try removing each ingredient in priority order
	for _, removedIngredient in ipairs(sortedIngredients) do
		local reduced = {}
		for _, ing in ipairs(ingredients) do
			if ing ~= removedIngredient then
				table.insert(reduced, ing)
			end
		end

		local baseId = CoffeeModule.GetId(reduced)
		local baseConfig = lookupTable[baseId]

		if baseConfig then
			-- Found a valid base, recurse to find the full path
			local basePath = findInstructionPathIds(reduced)
			if basePath then
				table.insert(basePath, removedIngredient)
				return basePath
			end
		end
	end
	task.spawn(function()
		error("CRITICAL ERROR: DISCONNECTED RECIPE PATH: " .. table.concat(ingredients, ", "))
	end)
	return nil
end

-- Recursively find a path of ingredients to add, starting from a base ingredient
local function findInstructionPath(ingredients: { string }): { string }?
	-- Base case: single ingredient is the starting point
	if #ingredients == 1 then
		return { getIngredientDisplayName(ingredients[1]) }
	end

	-- Sort by removal priority (later in config = removed first)
	local sortedIngredients = sortByRemovalPriority(ingredients)

	-- Try removing each ingredient in priority order
	for _, removedIngredient in ipairs(sortedIngredients) do
		local reduced = {}
		for _, ing in ipairs(ingredients) do
			if ing ~= removedIngredient then
				table.insert(reduced, ing)
			end
		end

		local baseId = CoffeeModule.GetId(reduced)
		local baseConfig = lookupTable[baseId]

		if baseConfig then
			-- Found a valid base, recurse to find the full path
			local basePath = findInstructionPath(reduced)
			if basePath then
				table.insert(basePath, getIngredientDisplayName(removedIngredient))
				return basePath
			end
		end
	end
	task.spawn(function()
		error("CRITICAL ERROR: DISCONNECTED RECIPE PATH: " .. table.concat(ingredients, ", "))
	end)
	return nil
end

for _, config in ipairs(CoffeeConfigArray) do
	if not config.Ingredients then
		continue
	end
	local pathIds = findInstructionPathIds(config.Ingredients)
	local pathDisplay = findInstructionPath(config.Ingredients)
	if pathDisplay and #pathDisplay > 1 then
		config.Instruction = table.concat(pathDisplay, " -> ")
	end
	config.RecipePath = pathIds
end

-- Assign Image from model PackageLink
for _, config in ipairs(CoffeeConfigArray) do
	local model = ReplicatedStorage.Shared.Models:FindFirstChild(config.Id)
	if model then
		local ingredientPackageLink = model:FindFirstChildWhichIsA("PackageLink")
		if ingredientPackageLink then
			local numericId = string.match(tostring(ingredientPackageLink.PackageId), "%d+")
			config.Image = string.format("rbxthumb://type=Asset&id=%s&w=150&h=150", numericId)
			-- https://thumbnails.roblox.com/v1/assets?assetIds={numericId}&size=150x150&format=Png&isCircular=false
			-- https://thumbnails.roblox.com/v1/assets?assetIds=125898228066517&size=150x150&format=Png&isCircular=false
			-- this is for outside of roblox studio.
			--[[
{
  "data": [
    {
      "targetId": 102154813642189,
      "state": "Completed",
      "imageUrl": "https://tr.rbxcdn.com/180DAY-848b71767de056350120a75d0ee2ae4d/30/30/Model/Png/noFilter",
      "version": "TN3.5"
    }
  ]
}
			]]
		end
	end
end

-- Export the keyed config for external use
CoffeeModule.Config = CoffeeConfig
CoffeeModule.Array = CoffeeConfigArray

local function getBasePriceFromIngredients(ingredients: { string }?): number
	if not ingredients or #ingredients == 0 then
		return 0
	end

	local total = 0
	for _, ingredient in ingredients do
		-- local appliance = CoffeeModule.IngredientToApplianceLookup[ingredient]
		-- if appliance and appliance.RequiredLevel then
		-- 	total += appliance.RequiredLevel
		-- else
		-- Fallback keeps pricing stable even if progression mapping is missing.
		total += 1
		-- end
	end

	return total / #ingredients
end

-- Ensure each config has a derived Price that can be reused by UI and server logic.
for _, config in ipairs(CoffeeConfigArray) do
	if config.Price == nil then
		config.Price = getBasePriceFromIngredients(config.Ingredients)
	end
end
CoffeeModule.Unorderables = {
	chocolate = true,
	ice = true,
	icedwater = true,
	water = true,
	matchapowder = true,
	teabag = true,
	carbonator = true,
	icecream = true,
	milkywater = true,
	icedespresso = true,
	icedmilkywater = true,
	lemon = true,
}

for i, config in CoffeeConfigArray do
	local ingredientMissing = false
	for j, ingredient in config.Ingredients or {} do
		if not CoffeeModule.Config[ingredient] then
			ingredientMissing = true
		end
	end
	if not ingredientMissing then
		continue
	end

	-- unorderables if an ingredient is commented
	CoffeeModule.Unorderables[config.Id] = true
end

function CoffeeModule.Craft(ingredients: { string }): CoffeeConfigType?
	-- Support any number of items
	if #ingredients == 0 then
		return nil
	end

	-- Get resulting Id and lookup
	local resultId = CoffeeModule.GetId(ingredients)
	return lookupTable[resultId]
end

function CoffeeModule.GetBasePrice(itemId: string): number
	local config = CoffeeConfig[itemId]
	if not config then
		return 0
	end
	if config.Price == nil then
		config.Price = getBasePriceFromIngredients(config.Ingredients)
	end
	return config.Price or 0
end

function CoffeeModule.GetScoredPrice(itemId: string, score: number): number
	return math.floor(math.max(0, score) * CoffeeModule.GetBasePrice(itemId))
end

return CoffeeModule
