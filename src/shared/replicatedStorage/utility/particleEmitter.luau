-- Roblox Services
local Debris = game:GetService("Debris")

-- Utility
local AnchorHandler = require(script.Parent.AnchorHandler)
local TypeCheck = require(script.Parent.TypeCheck)

-->
local function emit(particleEmitter: ParticleEmitter, parent: Instance)
	if not particleEmitter or not particleEmitter:IsA("ParticleEmitter") then
		return
	end

	local rate = particleEmitter:GetAttribute("Rate") or particleEmitter:GetAttribute("EmitCount")
	if not TypeCheck.number(rate) then
		return
	end

	particleEmitter:Emit(rate)
end

-- Main Function
return function(particleContainer: Attachment | Folder | Model | BasePart | ParticleEmitter, parent: any)
	assert(TypeCheck.Instance(particleContainer), "particleContainer arg must be an Instance")
	assert(TypeCheck.Instance(parent), "parent arg must be an Instance")

	if particleContainer:IsA("Model") or particleContainer:IsA("BasePart") then
		particleContainer:PivotTo(parent:GetPivot())
		AnchorHandler(particleContainer, true)
	end

	local clone = particleContainer:Clone()
	clone.Parent = parent
	Debris:AddItem(clone, 5)

	emit(clone :: ParticleEmitter, parent)
	for _, desc in pairs(clone:GetDescendants()) do
		emit(desc, parent)
	end
end
