local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local callbacks = {}
local function signal(name)
 return { Connect = function(_, callback) callbacks[name] = callback; return { Disconnect = function() end } end }
end
local layout = { Padding = r.UDim.new(0, 0), AbsoluteContentSize = r.Vector2.new(150, 1200), GetPropertyChangedSignal = function() return signal("layout") end }
local card = { Size = r.UDim2.fromScale(0.5, 0.5), SizeConstraint = r.Enum.SizeConstraint.RelativeYY, IsA = function() return true end, SetAttribute = function(self, name, value) self[name] = value end }
local children = {card}
local frame = {
 AbsoluteSize = r.Vector2.new(700, 300),
 WaitForChild = function() return layout end,
 FindFirstChildOfClass = function() return nil end,
 GetChildren = function() return children end,
 GetPropertyChangedSignal = function() return signal("resize") end,
 ChildAdded = signal("added"),
}
local module = luau.load(fs.readFile("src/shared/replicatedStorage/utility/scrollingCanvas.luau"), { environment = { Enum = r.Enum, UDim = r.UDim, UDim2 = r.UDim2 } })()
module.Connect(frame)
assert(card.Size == r.UDim2.fromOffset(150, 150))
assert(card.DefaultSize == card.Size)
local clone = table.clone(card)
table.insert(children, clone)
callbacks.added(clone)
assert(clone.Size == r.UDim2.fromOffset(150, 150), "Growing the canvas must not widen cards")
frame.AbsoluteSize = r.Vector2.new(900, 400)
callbacks.resize()
assert(card.Size == r.UDim2.fromOffset(200, 200) and clone.DefaultSize == clone.Size)
print("RelativeYY scrolling cards preserve square size across cloning and resizing")
