local M = require "GMAW/Model"
local active = {}
function getActivatedMods() return {contains=function(_, id) return active[id] == true end} end
ItemTag = {SCREWDRIVER="screwdriver", WRENCH="wrench", PIPE_WRENCH="pipe_wrench"}
local gun = {class="HandWeapon", isRanged=function() return true end, getModID=function() return "MarzGuns" end}
assert(not M.enabled())
active.MarzGuns = true
assert(M.enabled() and M.supported(gun))
active.SimpleSuppressors = true
local patched = {class="HandWeapon", isRanged=function() return true end,
    getModID=function() return "SimpleSuppressors" end}
for _, name in ipairs({"Base.AssaultRifle", "Base.JS3T_Shotgun", "Base.JS14_Rifle"}) do
    patched.getFullType=function() return name end
    assert(M.supported(patched), "Simple Suppressors override must retain vanilla workbench access: " .. name)
end
patched.getFullType=function() return "Base.UnrelatedAddonGun" end
assert(not M.supported(patched), "Base namespace alone does not grant support")
patched.getFullType=function() return "SimpleSuppressors.Suppressor_556" end
assert(not M.supported(patched), "addon parts cannot masquerade as supported firearms")
active.SimpleSuppressors = nil
for _, slot in ipairs(M.slots) do
    local groups = M.toolGroups(slot)
    assert(#groups == 1 and #groups[1] == 1 and groups[1][1] == ItemTag.SCREWDRIVER)
end
assert(M.toolKey(gun) == "Screwdriver")
active.GunsOfMarz = true
assert(not M.enabled() and not M.supported(gun), "mixed GoM versions fail closed")
active.MarzGuns = nil
assert(M.enabled() and #M.toolGroups("Barrel") == 2 and #M.toolGroups("Foregrip") == 0)
active.GunsOfMarz, active.MarzGuns = nil, true
-- A legacy-only installation has neither of these current GoM symbols.
modules["MarzWeapons/ISUI/RequiredToolVisualEquipt"] = nil
MarzGuns_AttachAndDetach = nil
modules["MarzWeapons/Hooks/UpgradeRemoveUpgradeReequipt"] = true
ISUpgradeWeapon.complete = function() end
ISRemoveWeaponUpgrade.GMAWCompletionReturnFixed = nil
ISRemoveWeaponUpgrade.complete = function() return false end
