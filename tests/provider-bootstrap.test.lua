-- A separate VM proves startup without any installed Gunworks Lua.
providerMods = {GaelGunStore_B42=true}
function getActivatedMods() return {contains=function(_, id) return providerMods[id] == true end} end
local originalRequire = require
providerForbiddenRequires = 0
function require(name)
    if name:match("^WeaponSystems/") or name:match("^MarzWeapons/") then
        providerForbiddenRequires = providerForbiddenRequires + 1
        error("Gael-only loaded GoM dependency: " .. name)
    end
    return originalRequire(name)
end
for name in pairs(modules) do
    if name:match("^WeaponSystems/") or name:match("^MarzWeapons/") then modules[name] = nil end
end
ItemTag = {SCREWDRIVER="Screwdriver",WRENCH="Wrench",PIPE_WRENCH="PipeWrench"}
ItemType = {WEAPON_PART="weaponpart"}
function sendRemoveItemFromContainer() end
function sendAddItemToContainer() end
function syncHandWeaponFields() end
modules["FixCode/GGS_WeaponPartTimedActionFix"] = {}
modules["GGS_AttachmentDependencies"] = {
    isSlotUnlocked=function() return true end,
    isSlotDependent=function() return false end,
    getProviderUnlocks=function() return {} end,
}
