--[[
	Basic dependency graph for structs created within a namespace
]]

local current: { [number]: any }?
local currentName: string

local namespacesdependencies = {}

function namespacesdependencies.start(name: string)
	current = {} :: { [number]: any }
	currentName = name
end

function namespacesdependencies.add(data)
	if not current then
		return
	end

	table.insert(current, data)
end

function namespacesdependencies.currentLength()
	return if current then #current else 0
end

function namespacesdependencies.currentName()
	return currentName
end

function namespacesdependencies.empty(): { [number]: any }
	if current == nil then
		return {}
	end

	local result = current
	current = nil

	return result
end

return namespacesdependencies
