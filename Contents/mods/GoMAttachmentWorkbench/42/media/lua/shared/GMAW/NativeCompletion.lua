-- Preserve upstream mutations and explicit failures; normalize a successful
-- nil return to the Boolean required by B42 NetTimedAction.perform.
require "WeaponSystems/Hooks/WeaponUpgradeHooks"
-- Load the active GoM completion hook before applying the outermost repair.
-- Current CanShoot and the Old Version hook both drop completion returns.
if getActivatedMods():contains("GunsOfMarz") then
    require "MarzWeapons/Hooks/CanShoot"
end
if getActivatedMods():contains("MarzGuns") then
    require "MarzWeapons/Hooks/UpgradeRemoveUpgradeReequipt"
end
if not ISUpgradeWeapon.GMAWCompletionReturnFixed then
    local complete = ISUpgradeWeapon.complete
    function ISUpgradeWeapon:complete()
        local result = complete(self)
        if result == nil then return true end
        return result
    end
    ISUpgradeWeapon.GMAWCompletionReturnFixed = true
end
if not ISRemoveWeaponUpgrade.GMAWCompletionReturnFixed then
    local complete = ISRemoveWeaponUpgrade.complete
    function ISRemoveWeaponUpgrade:complete()
        local result = complete(self)
        if result == nil then return true end
        return result
    end
    ISRemoveWeaponUpgrade.GMAWCompletionReturnFixed = true
end
