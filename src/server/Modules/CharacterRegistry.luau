--!strict
local CharacterRegistry = {}

local idToModel: { [string]: Model } = {}
local modelToId: { [Model]: string } = {}

function CharacterRegistry.Register(id: string, model: Model)
	idToModel[id] = model
	modelToId[model] = id
end

function CharacterRegistry.Unregister(id: string)
	local model = idToModel[id]
	if model then
		modelToId[model] = nil
	end
	idToModel[id] = nil
end

function CharacterRegistry.GetModel(id: string): Model?
	return idToModel[id]
end

function CharacterRegistry.GetId(model: Model): string?
	return modelToId[model]
end

return CharacterRegistry
