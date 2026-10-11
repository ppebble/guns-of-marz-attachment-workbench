-- Optional GoM/Gunworks integration. Gael-only sessions never load WeaponSystems.
local F = {}
function F.enabled()
    local mods = getActivatedMods()
    return mods:contains("GunsOfMarz") ~= mods:contains("MarzGuns")
end
local function no() return false end
local function none() return nil end
local function optional(path, defaults)
    return setmetatable({}, {__index = function(_, key)
        if F.enabled() then return require(path)[key] end
        return defaults[key]
    end})
end
F.Required = optional("WeaponSystems/Utils/RequiredAttachment", {
    Dependencies={}, AnyDependencies={}, RequiresParent=no,
    IsRemovalBlocked=no, IsInstallationBlocked=no,
})
F.Permanent = optional("WeaponSystems/Utils/PreventRemovals", {IsPermanent=no})
F.Universal = optional("WeaponSystems/Utils/UniversalAttachment", {
    GetGenericItemTypeForOutcome=none, CanInstallOutcome=no,
})
F.Exclusives = optional("WeaponSystems/Utils/UpgradeExclusives", {Exclusives={}, IsBlockedByExclusive=no})
F.Underbarrel = optional("WeaponSystems/Utils/Underbarrel", {UnderbarrelAttachments={}, IsWeaponInUnderbarrelMode=no})
F.Railing = optional("WeaponSystems/Utils/Railing", {AcceptedAccessories={}})
function F.loadActions()
    require "TimedActions/ISUpgradeWeapon"
    require "TimedActions/ISRemoveWeaponUpgrade"
    if F.enabled() then require "WeaponSystems/Hooks/WeaponUpgradeHooks" end
    if getActivatedMods():contains("GaelGunStore_B42") then
        require "FixCode/GGS_WeaponPartTimedActionFix"
    end
end
return F
