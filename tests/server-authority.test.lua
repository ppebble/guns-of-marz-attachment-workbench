local M = require "GMAW/Model"
local Required = require "WeaponSystems/Utils/RequiredAttachment"
local Exclusives = require "WeaponSystems/Utils/UpgradeExclusives"
local oldSupported = M.supported
M.supported = function() return true end
Required.IsInstallationBlocked = function() return false end
Required.IsRemovalBlocked = function() return false end
Exclusives.IsBlockedByExclusive = function() return false end

local weapon = item("MarzGuns.M4A1", 90)
weapon.parts = {}
function weapon:getWeaponPart(slot) return self.parts[slot] end
function weapon:attachWeaponPart(_, part) self.parts[part:getPartType()] = part end
function weapon:detachWeaponPart(_, part) self.parts[part:getPartType()] = nil end
local part = item("MarzGuns.Scope", 91, "Scope")
local inv = inventory({ weapon, part })
function inv:getItemById(id)
    for _, value in ipairs(self.values) do if value:getID() == id then return value end end
end
local player = { getInventory = function() return inv end }
local removed, added, synced, replaced = nil, nil, nil, nil
function sendRemoveItemFromContainer(_, value) removed = value end
function sendAddItemToContainer(_, value) added = value end
function sendItemStats(value) synced = value end
function sendReplaceItemInContainer(_, old, new) replaced = {old=old,new=new} end
function syncHandWeaponFields() end

gmawServerCommand("GMAW", "apply", player, {
    kind="install", weaponID=90, partID=91, slot="Scope", fullType="MarzGuns.Scope",
})
assert(weapon.parts.Scope == part and removed == part and not added and synced == weapon
    and replaced and replaced.old == weapon and replaced.new == weapon)

gmawServerCommand("GMAW", "apply", player, {
    kind="detach", weaponID=90, partID=91, slot="Scope",
})
assert(not weapon.parts.Scope and added == part)
M.supported = oldSupported
