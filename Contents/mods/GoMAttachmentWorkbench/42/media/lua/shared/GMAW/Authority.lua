local M = require "GMAW/Model"
local Required = require "WeaponSystems/Utils/RequiredAttachment"
local Exclusives = require "WeaponSystems/Utils/UpgradeExclusives"
local Universal = require "WeaponSystems/Utils/UniversalAttachment"

local A = {}

local function itemByID(inventory, id)
    return inventory and id and inventory:getItemById(id) or nil
end

local function validArgs(args)
    return type(args) == "table" and type(args.kind) == "string"
        and type(args.weaponID) == "number" and type(args.slot) == "string"
end

-- This is deliberately server-safe: client input only selects IDs already in
-- the caller's recursive inventory. The server recomputes every mutable fact.
function A.apply(player, args)
    if not player or not validArgs(args) then return false, "Invalid" end
    local inventory = player:getInventory()
    local weapon = itemByID(inventory, args.weaponID)
    if not weapon or not M.supported(weapon) then return false, "Weapon" end

    local installed = weapon:getWeaponPart(args.slot)
    if args.kind == "detach" then
        if not installed or (args.partID and installed:getID() ~= args.partID)
            or M.permanent(installed) or Required.IsRemovalBlocked(weapon, installed:getFullType())
            or not installed:canDetach(player, weapon) then return false, "Detach" end
        weapon:detachWeaponPart(player, installed)
        inventory:AddItem(installed)
        return true, installed, "add"
    end

    if args.kind ~= "install" or type(args.partID) ~= "number" or type(args.fullType) ~= "string"
        or installed or Required.IsInstallationBlocked(weapon, args.fullType)
        or Exclusives.IsBlockedByExclusive(weapon, args.fullType) then return false, "Install" end

    local consumed = itemByID(inventory, args.partID)
    if not consumed or consumed:isBroken() then return false, "Part" end
    local attached = consumed
    if args.generic then
        if not Universal.CanInstallOutcome(weapon, args.fullType, player) then return false, "Tools" end
        attached = instanceItem(args.fullType)
        if not attached then return false, "Outcome" end
    elseif consumed:getFullType() ~= args.fullType or consumed:getPartType() ~= args.slot
        or not consumed:canAttach(player, weapon) then return false, "Part" end

    weapon:attachWeaponPart(player, attached)
    inventory:Remove(consumed)
    return true, consumed, "remove"
end

return A
