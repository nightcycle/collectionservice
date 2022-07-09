return function(coreGui)
	local packages = script.Parent.Parent
	local Maid = require(packages:WaitForChild("maid"))
	local Signal = require(packages:WaitForChild("signal"))
	local Service = require(script.Parent)

	for i, v in ipairs(game:GetService("CollectionService"):GetTagged("Maid")) do
		v:Destroy()
	end
	for i, v in ipairs(game:GetService("CollectionService"):GetTagged("Maid2")) do
		v:Destroy()
	end
	local maid1 = Maid.new()
	maid1.Destroying = Signal.new()
	maid1:GiveTask(function()
		maid1.Destroying:Fire()
	end)

	local maid2 = Maid.new()
	maid2.Destroying = Signal.new()
	maid2:GiveTask(function()
		maid2.Destroying:Fire()
	end)

	local addSignal2 = Service:GetInstanceAddedSignal("Maid", "Maid2")
	local connection2 = addSignal2:Connect(function(m)
		print("Added maid", m)
		m:GiveTask(function()
			print("M uh oh")
		end)
	end)

	local maid3 = {}
	maid3.Destroying = Signal.new()
	function maid3:Destroy()
		self.Destroying:Fire()
	end
	function maid3:GiveTask()
		
	end

	Service:AddTag(maid1, "Maid")
	Service:AddTag(maid2, "Maid")
	print("1")
	Service:AddTag(maid2, "Maid2")
	print("2")
	Service:AddTag(maid3, "Maid", "Maid3")

	local maids2 = Service:GetTagged("Maid", "Maid2")
	print("Maids2", maids2)
	local m2 = maids2[1]
	m2:GiveTask(function()
		print("Destroy haha")
	end)
	m2:Destroy()
	maid3:Destroy()
	local oops = {maid1, maid2}

	local parts = {}
	for i=1, 10 do
		local part = Instance.new("Part", workspace)
		part.Name = "Part"..tostring(i)
		Service:AddTag(part, "A", "B")
		if i == 1 then
			Service:AddTag(part, "C", "D")
		end
		if i % 2 == 0 then
			Service:AddTag(part, "E")
		end
		table.insert(parts, part)
	end
	
	Service:RemoveTag(parts[4], "E")

	local removeSignal = Service:GetInstanceRemovedSignal("A", "D")
	local connection = removeSignal:Connect(function(part)
		print("Removed it", part)
	end)

	local aParts = Service:GetTagged("A")
	local abeParts = Service:GetTagged("A","B", "E")
	local adParts = Service:GetTagged("A", "D")

	Service:RemoveTag(parts[1], "D")

	return function()
		print("RESULT", Service)
		for i, part in ipairs(parts) do
			part:Destroy()
		end
		removeSignal:Destroy()
		connection:Disconnect()
		for i, obj in ipairs(oops) do
			obj:Destroy()
		end
		addSignal2:Destroy()
		connection2:Disconnect()
	end
end