
local CollectionService: CollectionService = game:GetService("CollectionService")
local packages = script.Parent

local Signal: Signal = require(packages:WaitForChild("signal"))
local Maid: Maid = require(packages:WaitForChild("maid"))

local ReplicateEvent: RemoteEvent = script:WaitForChild("ReplicateEvent")
local Tags: Folder = script:WaitForChild("Tags")

local Service: CollectionService = {}
Service.__index = Service

local currentSelf: CollectionService = {}


function registerTag(self, tag: Tag)
	if self.Tags[tag] ~= nil then return end
	self.Tags[tag] = tagToKey(tag)
	self.TagKeys[currentSelf.Tags[tag]] = tag
end

function deregisterTag(self, tag: Tag)
	if self.Tags[tag] == nil then return end
	self.TagKeys[currentSelf.Tags[tag]] = nil
	self.Tags[tag] = nil
end


function toCollectible(self, val: Destructible | Instance)
	if val == nil then return end
	if typeof(val) == "table" then
		-- print("A", val)
		if val.Destroying and val.Destroy then
			-- print("B", val)
			if self.RegisteredTables[val] then return self.RegisteredTables[val] end
			-- print("C", val)
			local inst = Instance.new("Folder", Tags)

			local connection: RBXScriptConnection
			connection = val.Destroying:Connect(function()
				-- print("DESTROYING COLLECTIBLE FOLDER")
				inst:Destroy()
				connection:Disconnect()
				self.RegisteredTables[val] = nil
				self.RegisteredTables[inst] = nil
			end)

			self._Maid:GiveTask(inst)
			self._Maid:GiveTask(connection)

			self.RegisteredTables[val] = inst
			self.RegisteredTables[inst] = val
			return inst
		else
			error("Bad destructible")
		end
	elseif typeof(val) == "Instance" then
		return val
	else
		error("Bad collectible: "..tostring(typeof(val)))
	end
end

function fromCollectible(self, inst: Instance)
	if inst == nil then return end
	return self.RegisteredTables[inst] or inst
end

function removeCollectible(self, val: Destructible | Instance)
	local inst = self.RegisteredTables[val]
	if inst and inst:IsA("Instance") then
		inst:Destroy()
	end
end

function comboCollection(self, tags, getSignalFunction)

	local keys = {}
	for i, tag: Tag in ipairs(tags) do
		registerTag(self, tag)
		table.insert(keys, self.Tags[tag])
	end

	local maid = Maid.new()

	local signal: Signal = Signal.new()
	signal._bindableEvent.Destroying:Connect(function()
		maid:Destroy()
	end)

	for i, key: string in ipairs(keys) do
		local subSignal = getSignalFunction(key)
		maid:GiveTask(subSignal:Connect(function(collectible: Instance)
			local hasAll = true
			local inst = fromCollectible(self, collectible)
			for j, k in ipairs(keys) do
				if not CollectionService:HasTag(collectible, k) then
					hasAll = false
				end
			end
			if hasAll and inst ~= nil then
				signal:Fire(inst)
			end
		end))
	end

	return signal
end

function Service:GetInstanceAddedSignal(...: Tag): RBXScriptSignal
	local tags: {[number]: Tag} = {...}
	local signal = comboCollection(self, tags, function(key)
		return CollectionService:GetInstanceAddedSignal(key)
	end)
	self._Maid:GiveTask(signal)
	return signal
end

function Service:GetInstanceRemovedSignal(...: Tag): RBXScriptSignal
	local tags: {[number]: Tag} = {...}
	local signal = comboCollection(self, tags, function(key)
		return CollectionService:GetInstanceRemovedSignal(key)
	end)
	self._Maid:GiveTask(signal)
	return signal
end

function Service:GetTagged(...: Tag)
	local tagGroups = {}
	local tags: {[number]: Tag} = {...}
	local keys: {[number]: string} = {}
	for i, tag:Tag in ipairs(tags) do
		registerTag(self, tag)
		keys[i] = self.Tags[tag]
	end
	for i, key in ipairs(keys) do
		tagGroups[key] = CollectionService:GetTagged(key)
	end
	table.sort(keys, function(a,b)
		local aGroup = tagGroups[a]
		local bGroup = tagGroups[b]
		return #aGroup < #bGroup
	end)
	-- print("GROUPS", tagGroups)
	-- print("KEYS", keys)
	local registered = {}
	for i, part in ipairs(tagGroups[keys[1] or ""] or {}) do
		registered[part] = true
	end
	local function findOverlap(index)
		index = index or 1
		if index > #keys then return end
		local key = keys[index]
		local group = tagGroups[key]
		if not group then return end

		local groupRegistry = {}
		for i, inst in pairs(group) do
			groupRegistry[inst] = true
		end

		for k, part in pairs(registered) do
			if groupRegistry[part] == nil then
				registered[part] = nil
			end
		end

		findOverlap(index + 1)
	end
	findOverlap()
	-- print("Registered", registered)
	-- print("Groups", tagGroups)
	local list = {}
	for k, _ in pairs(registered) do
		-- print("K", k)
		table.insert(list, fromCollectible(self, k))
	end
	-- print("LIST", list)
	return list
end

function Service:GetTags(inst: Instance | Destructible): {[number]: Tag}
	local keys = CollectionService:GetTags(toCollectible(self, inst))
	local tags = {}
	for i, key in ipairs(keys) do
		tags[i] = self.TagKeys[key]
	end
	return tags
end

function tagToKey(tag: Tag)
	return tostring(tag)
end

function Service:AddTag(inst: Instance | Destructible, ...:Tag)
	local function addSpecificTag(tag: Tag)
		registerTag(self, tag)
		local key = self.Tags[tag]
		local collectible = toCollectible(self, inst)
		CollectionService:AddTag(collectible, key)
	end

	for i, tag in ipairs({...}) do
		addSpecificTag(tag)
	end
end

function Service:HasTag(inst: Instance | Destructible, ...:Tag)
	local function hasSpecificTag(tag: Tag)
		registerTag(self, tag)
		local key = self.Tags[tag]

		return CollectionService:HasTag(toCollectible(self, inst), key)
	end
	local hasTag = true
	for i, tag in ipairs({...}) do
		if not hasSpecificTag(tag) then
			hasTag = false
		end
	end
	return hasTag
end

function Service:RemoveTag(inst: Instance | Destructible, ...:Tag)
	local function removeTag(tag: Tag)
		registerTag(self, tag)
		local key = self.Tags[tag]
		local c = toCollectible(self, inst)
		CollectionService:RemoveTag(c, key)
		if #CollectionService:GetTags(c) == 0 then
			removeCollectible(self, inst)
		end
		if #CollectionService:GetTagged(key) == 0 then
			deregisterTag(self, tag)
		end
	end
	for i, tag in ipairs({...}) do
		removeTag(tag)
	end
end

function Service.new()
	if currentSelf._Maid then
		currentSelf._Maid:Destroy()
	end
	for k, v in pairs(currentSelf.RegisteredTables or {}) do
		currentSelf.RegisteredTables[k] = nil
	end
	for k, v in pairs(currentSelf) do
		currentSelf[k] = nil
	end
	currentSelf._Maid = Maid.new()
	currentSelf.RegisteredTables = {}
	currentSelf.Tags = {}
	currentSelf.TagKeys = {}
	setmetatable(currentSelf, Service)
	return currentSelf
end

function Service:Destroy()
	Service.new()
end

export type Destructible = {
	Destroy: (self: Destructible) -> nil,
	Destroying: RBXScriptSignal,
}

export type Collectible = Instance | Destructible

export type Tag = any

export type CollectionService = {
	GetInstanceAddedSignal: (self: CollectionService, tag: string) -> RBXScriptSignal,
	GetInstanceRemovedSignal: (self: CollectionService, tag: string) -> RBXScriptSignal,

	GetTagged: (self: CollectionService, ...Tag) -> {[number]: Collectible},
	GetTags: (self: CollectionService, ...Tag) -> {[number]: string},
	HasTag: (self: CollectionService, inst: Collectible, ...Tag) -> boolean,
	RemoveTag: (self: CollectionService, inst: Collectible, ...Tag) -> nil,
	new: () -> CollectionService,

	Tags: {[Tag]: any},
}

export type Maid = {
	new: () -> Maid,
	GiveTask: (self: Maid, Instance | Destructible | RBXScriptConnection) -> nil,
	__newindex: (self: Maid, k: any, v: Destructible?) -> nil,
} & Destructible

export type Signal = {
	new: () -> Signal,
	Connect: (self: Signal, (...any?) -> nil) -> RBXScriptConnection
}


return Service.new()

