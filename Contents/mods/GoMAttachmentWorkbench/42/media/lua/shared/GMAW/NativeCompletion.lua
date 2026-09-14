-- Gunworks normal (non-generic) removal completes its mutations but omits
-- the Boolean result required by B42 NetTimedAction.perform. Keep upstream
-- behavior and explicit failures; normalize only a successful nil return.
require "WeaponSystems/Hooks/WeaponUpgradeHooks"
-- Old Version wraps both completion methods for animation sync and drops
-- their return values. Load that hook first so our Boolean repair is outermost.
if getActivatedMods():contains("MarzGuns") then
    require "MarzWeapons/Hooks/UpgradeRemoveUpgradeReequipt"
    if not ISUpgradeWeapon.GMAWCompletionReturnFixed then
        local complete = ISUpgradeWeapon.complete
        function ISUpgradeWeapon:complete()
            local result = complete(self)
            if result == nil then return true end
            return result
        end
        ISUpgradeWeapon.GMAWCompletionReturnFixed = true
    end
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
