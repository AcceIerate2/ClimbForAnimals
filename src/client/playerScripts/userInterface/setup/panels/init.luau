local Panels = {}

-- LifeCycle
function Panels:Init(player: Player)
	local PanelsGui = player.PlayerGui:WaitForChild("Panels")
	for _, panelFrame: Frame in pairs(PanelsGui:GetChildren()) do
		panelFrame.Visible = false
		panelFrame.Position = UDim2.fromScale(0.5, 1.5)
	end
end

return Panels
