local Authority = require "GMAW/Authority"
local M = require "GMAW/Model"
local Required = require "WeaponSystems/Utils/RequiredAttachment"
local Exclusives = require "WeaponSystems/Utils/UpgradeExclusives"
local Universal = require "WeaponSystems/Utils/UniversalAttachment"
local oldSupported = M.supported
M.supported = function() return true end
Required.IsInstallationBlocked = function() return false end
Required.IsRemovalBlocked = function() return false end
Exclusives.IsBlockedByExclusive = function() return false end
Universal.CanInstallOutcome = function() return true end

local rail = item("MarzGuns.Picatinny_Rail", 11, "RailUp")
local weapon = item("MarzGuns.M4A1", 10)
weapon.parts = {}
function weapon:getWeaponPart(slot) return self.parts[slot] end
function weapon:attachWeaponPart(_, part) self.parts[part:getPartType()] = part end
function weapon:detachWeaponPart(_, part) self.parts[part:getPartType()] = nil end
local inv = inventory({ weapon, rail })
function inv:getItemById(id)
    for _, value in ipairs(self.values) do if value:getID() == id then return value end end
end
local player = { getInventory = function() return inv end }

local ok, consumed, direction = Authority.apply(player, {
    kind="install", weaponID=10, partID=11, slot="RailUp", fullType="MarzGuns.Picatinny_Rail",
})
assert(ok and consumed == rail and direction == "remove")
assert(weapon.parts.RailUp == rail and not inv:getItemById(11))

ok, consumed, direction = Authority.apply(player, {
    kind="detach", weaponID=10, partID=11, slot="RailUp",
})
assert(ok and consumed == rail and direction == "add")
assert(not weapon.parts.RailUp and inv:getItemById(11) == rail)

assert(not Authority.apply(player, {
    kind="install", weaponID=10, partID=99, slot="RailUp", fullType="MarzGuns.Picatinny_Rail",
}), "server never accepts an item ID absent from the caller inventory")

local generic = item("MarzGuns.GenericRail", 12, "RailUp")
inv:AddItem(generic)
function instanceItem(fullType) return item(fullType, 99, "RailUp") end
ok, consumed, direction = Authority.apply(player, {
    kind="install", weaponID=10, partID=12, slot="RailUp", fullType="MarzGuns.Picatinny_Rail_Up", generic=true,
})
assert(ok and consumed == generic and direction == "remove")
assert(weapon.parts.RailUp:getFullType() == "MarzGuns.Picatinny_Rail_Up" and not inv:getItemById(12))
M.supported = oldSupported
