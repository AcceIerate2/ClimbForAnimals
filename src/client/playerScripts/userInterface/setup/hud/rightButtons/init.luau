local RightButtons = {}

function RightButtons:Init(player: Player)
	self.Frame = player.PlayerGui:WaitForChild("Hud"):WaitForChild("RightMain"):WaitForChild("Right")
end

return RightButtons
