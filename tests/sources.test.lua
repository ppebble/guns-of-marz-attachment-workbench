local S = require "GMAW/Sources"
local inv = inventory({ item("owned", 10) })
local floor = item("part", 11)
local furniture = inventory({ item("part", 12) })
local vehicleInv = inventory({ item("part", 13) })
local blocked = inventory({ item("hidden", 14) })
local access, safe, locked, reachable = true, true, false, true
local square = { getX = function() return 5 end, getY = function() return 6 end, getZ = function() return 0 end }
local neighbor = {}
function square:canReachTo(other) return reachable end
local world = { getItem = function() return floor end }
local function object(container)
    return { getContainerCount = function() return 1 end, getContainerByIndex = function() return container end }
end
local lockObject = object(blocked)
lockObject.class = "IsoThumpable"; lockObject.isLockedToCharacter = function() return locked end
local vehicle = { getId = function() return 33 end, getPartCount = function() return 1 end,
    canAccessContainer = function() return access end,
    getPartByIndex = function() return { getItemContainer = function() return vehicleInv end } end }
function square:getWorldObjects() return javaList({}) end
function square:getObjects() return javaList({}) end
function square:getVehicleContainer() return nil end
function neighbor:getWorldObjects() return javaList({ world }) end
function neighbor:getObjects() return javaList({ object(furniture), lockObject }) end
function neighbor:getVehicleContainer() return vehicle end
local requested = 0
function getCell() return { getGridSquare = function(_, x, y, z)
    requested = requested + 1
    assert(math.abs(x - 5) <= 1 and math.abs(y - 6) <= 1 and z == 0)
    if x == 5 and y == 6 then return square end
    if x == 6 and y == 6 then return neighbor end
end } end
local player = { getInventory = function() return inv end, getCurrentSquare = function() return square end }
locked = true
local scan = S.scan(player)
assert(requested == 9 and #scan.entries == 4)
assert(#scan.byType.part == 3 and not scan.byID[14])
assert(scan.entries[1].item:getID() == 10 and scan.entries[2].item == floor)
access = false; scan = S.scan(player); assert(not scan.byID[13])
reachable = false; scan = S.scan(player); assert(#scan.entries == 1)
reachable = true
function isServer() return true end
SafeHouse = { isSafehouseAllowLoot = function(_, _) return safe end }
safe = false; scan = S.scan(player); assert(#scan.entries == 1)
function isServer() return false end
local child = item("nested", 22)
local bag = item("bag", 21)
bag.class = "InventoryContainer"
bag.getInventory = function() return inventory({ child }) end
inv.values = { bag }
scan = S.scan(player)
assert(scan.byID[22] and scan.byID[22].key == "0:player/bag:21")
-- A container refusing removal cannot be bypassed by recursively opening its bag.
inv.isRemoveItemAllowed = function() return false end
scan = S.scan(player)
assert(not scan.byID[21] and not scan.byID[22])

-- A nearby placed InventoryContainer (such as SaucedCarts) is scanned recursively.
local cartPart = item("cart-part", 31)
local cart = item("cart", 30)
cart.class = "InventoryContainer"
cart.getInventory = function() return inventory({ cartPart }) end
world.getItem = function() return cart end
scan = S.scan(player)
assert(scan.byID[31] and scan.byID[31].key == "1:floor:6:6:0/bag:30")

-- Nearby working tools are addressable with their source preserved for transfer.
ItemTag={SCREWDRIVER="screwdriver"}
local nearbyTool=item("tool", 23)
nearbyTool.hasTag=function(_, tag) return tag==ItemTag.SCREWDRIVER end
scan.entries={{item=nearbyTool,key="2:object",kind="Furniture"}}
assert(S.firstWorkingTag(scan,{ItemTag.SCREWDRIVER}).item==nearbyTool)
nearbyTool.isBroken=function() return true end
assert(not S.firstWorkingTag(scan,{ItemTag.SCREWDRIVER}))
