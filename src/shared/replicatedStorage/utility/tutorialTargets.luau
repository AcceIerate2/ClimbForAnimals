-- Resolve authored markers consistently for server proximity checks and client beams.
local Targets = {}

function Targets.GetCFrame(instance): CFrame?
	if not instance then
		return nil
	end
	if instance:IsA("CFrameValue") then
		return instance.Value
	elseif instance:IsA("Attachment") then
		return instance.WorldCFrame
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	elseif instance:IsA("Model") then
		return instance:GetPivot()
	end
	return nil
end

function Targets.GetSize(instance): Vector3
	if instance and instance:IsA("BasePart") then
		return instance.Size
	end
	return Vector3.zero
end

return Targets
