-- Gunworks normal (non-generic) removal completes its mutations but omits
-- the Boolean result required by B42 NetTimedAction.perform. Keep upstream
-- behavior and explicit failures; normalize only a successful nil return.
require "WeaponSystems/Hooks/WeaponUpgradeHooks"
if not ISRemoveWeaponUpgrade.GMAWCompletionReturnFixed then
    local complete = ISRemoveWeaponUpgrade.complete
    function ISRemoveWeaponUpgrade:complete()
        local result = complete(self)
        if result == nil then return true end
        return result
    end
    ISRemoveWeaponUpgrade.GMAWCompletionReturnFixed = true
end
