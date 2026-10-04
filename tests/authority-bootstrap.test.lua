-- Bounded native-action doubles; actual installed native hooks are tested separately.
authorityOriginalUpgrade = ISUpgradeWeapon.new
authorityOriginalRemove = ISRemoveWeaponUpgrade.new
function ISUpgradeWeapon:new(player, weapon, part, outcome)
    return {isValid=function() return not weapon.rejectNative end, complete=function()
        weapon:attachWeaponPart(player, outcome and instanceItem(outcome) or part)
        player:getInventory():Remove(part)
        sendRemoveItemFromContainer(player:getInventory(), part)
        return true
    end}
end
function ISRemoveWeaponUpgrade:new(player, weapon, slot)
    return {isValid=function() return not weapon.rejectNative end, complete=function()
        local part = weapon:getWeaponPart(slot)
        weapon:detachWeaponPart(player, part)
        player:getInventory():AddItem(part)
        sendAddItemToContainer(player:getInventory(), part)
        return true
    end}
end
function sendRemoveItemFromContainer() end
function sendAddItemToContainer() end
