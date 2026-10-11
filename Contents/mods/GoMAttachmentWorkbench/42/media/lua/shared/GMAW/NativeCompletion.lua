-- Preserve upstream mutations and explicit failures; normalize a successful
-- nil return to the Boolean required by B42 NetTimedAction.perform.
local Framework = require "GMAW/Framework"
Framework.loadActions()
-- Gael and vanilla already return Booleans; this repair belongs only to GoM.
if not getActivatedMods():contains("GunsOfMarz") and not getActivatedMods():contains("MarzGuns") then
    return true
end
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
