-- Roblox Services
local HttpService = game:GetService("HttpService")

-- Utility
local InstanceCreator = require(script.Parent.InstanceCreator)
local TypeCheck = require(script.Parent.TypeCheck)

-->
local Module = {}

function Module.SetupHitbox(Parent: BasePart, Offset: Vector3, CustomProperties: { [string]: any }): BasePart | nil
	if not Parent or not Offset then
		error("One of the essential args were not given!")
	end
	local GUID = HttpService:GenerateGUID(false) :: string
	local Hitbox = InstanceCreator("Part", `Hitbox_{GUID}`, Parent) :: BasePart
	if not Hitbox then
		return
	end
	if TypeCheck.table(CustomProperties) then
		for PropertyName: string, PropertyValue in pairs(CustomProperties) do
			Hitbox[PropertyName] = PropertyValue
		end
	end

	Hitbox:PivotTo(Parent.CFrame * CFrame.new(0, 0, -2))

	return Hitbox
end

function Module.PartsInHitbox(Hitbox: BasePart): { BasePart }
	if not Hitbox then
		error("No hitbox Instance given!")
	end
	local PartsInPart = workspace:GetPartsInPart(Hitbox) :: { BasePart }
	return PartsInPart
end

function Module.CharactersInHitbox(Hitbox: BasePart): { Model }
	if not Hitbox then
		error("No hitbox Instance given!")
	end

	local ToReturn = {} :: { Model }

	local PartsInHitbox = Module.PartsInHitbox(Hitbox :: BasePart) :: { BasePart }
	if TypeCheck.table(PartsInHitbox) then
		for _Index, Part in pairs(PartsInHitbox) do
			local Parent = Part.Parent
			if Parent and Parent:IsA("Model") then
				local Humanoid = Parent:FindFirstChildOfClass("Humanoid") :: Humanoid | nil
				if Humanoid then
					-- character
					local ExistsInTable = table.find(ToReturn, Parent)
					if ExistsInTable then
						continue
					end
					table.insert(ToReturn, Parent)
				end
			end
		end
	end

	return ToReturn :: { Model }
end

return Module
