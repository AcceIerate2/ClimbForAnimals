-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local knit = require(ReplicatedStorage.src.Packages.knit)
local Signal = require(ReplicatedStorage.src.Packages.Signal)

-->
local FuseController = knit.CreateController({
	Name = "FuseController",
	Changed = Signal.new(),
	Pending = false,
	SelectingSlot = nil,
})

-- Private Methods
function FuseController:notify(message: string, success: boolean)
	self.NotificationController:Push({
		Message = message,
		Color = success and Color3.fromRGB(80, 255, 100) or Color3.fromRGB(255, 80, 80),
		Sound = success and "Cash" or "Decline",
	})
end

function FuseController:setSlot(slot: number, reference: string?)
	if self.Pending then
		return
	end
	self.Pending = true
	self.Changed:Fire()
	self.Service
		:SetSlot(slot, reference)
		:andThen(function(response)
			if response.Status then
				self.SelectingSlot = nil
			else
				self:notify(response.Reason or "Couldn't update the fuse machine.", false)
			end
		end)
		:catch(function(reason)
			warn(reason)
			self:notify("Couldn't update the fuse machine. Please try again.", false)
		end)
		:finally(function()
			self.Pending = false
			self.Changed:Fire()
		end)
end

-- Public Methods
function FuseController:ClickSlot(slot: number)
	if self.Pending then
		return
	end
	local state = self.DataController:GetValue("Fuse")
	if state.Slots[tostring(slot)] then
		self:setSlot(slot, nil)
	else
		self.SelectingSlot = slot
		self.Changed:Fire()
	end
end

function FuseController:SelectAnimal(reference: string)
	if self.SelectingSlot then
		self:setSlot(self.SelectingSlot, reference)
	end
end

function FuseController:CancelSelection()
	self.SelectingSlot = nil
	self.Changed:Fire()
end

-- LifeCycle
function FuseController:KnitInit()
	self.Service = knit.GetService("FuseService")
	self.DataController = knit.GetController("DataController")
	self.NotificationController = knit.GetController("NotificationController")
end

function FuseController:KnitStart()
	self.Service.Completed:Connect(function(name: string, variant: string)
		self:notify(`Fusion complete! You received a {variant} {name}!`, true)
	end)
end

return FuseController
