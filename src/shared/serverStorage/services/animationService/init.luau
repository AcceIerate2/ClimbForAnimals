-- Packages
local knit = require("@game/ReplicatedStorage/src/Packages/knit")

-->
local AnimationService = knit.CreateService({
	Name = "AnimationService",
	Client = {
		Play = knit.CreateSignal(),
	},
})

-- Public Methods
function AnimationService:PlayAnimation(player: Player, animationName: string)
	warn(player, animationName)
	self.Client.Play:Fire(player, animationName)
end

return AnimationService
