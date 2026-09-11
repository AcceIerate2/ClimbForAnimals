return function(parent: Instance, className: string?, props: { [string]: any }, timeout: number?)
	timeout = timeout or math.huge
	local start = os.clock()
	local found = false

	task.delay(5, function()
		if not found then
			local name = props.Name

			warn(
				`Infinite yield possible while waiting for {if name
					then `{className or "a descendant"} named "{name}"`
					else className or "a descendant"} in {parent:GetFullName()}`
			)
		end
	end)

	local function matches(instance: Instance)
		if className and not instance:IsA(className) then
			return false
		end

		for prop, value in pairs(props) do
			if instance[prop] ~= value then
				return false
			end
		end

		return true
	end

	for _, instance in parent:GetDescendants() do
		if matches(instance) then
			found = true
			return instance
		end
	end

	while os.clock() - start < timeout do
		local instance = parent.DescendantAdded:Wait()

		if matches(instance) then
			found = true
			return instance
		end
	end

	found = true
	return nil
end
