local M, P = require "GMAW/Model", require "GMAW/Planner"
local scripts, sequence = {}, 1000
ItemType = { WEAPON_PART = "base:weaponpart" }
ItemTag = { SCREWDRIVER = "screwdriver", WRENCH = "wrench", PIPE_WRENCH = "pipe_wrench" }
function getActivatedMods() return { contains = function(_, id) return id == "GunsOfMarz" end } end
function instanceItem(fullType)
    local r = installedRecords[fullType]
    if not r then return nil end
    sequence = sequence + 1
    local it = item(fullType, sequence, r.slot)
    it.class = r.type == "base:weaponpart" and "WeaponPart" or "HandWeapon"
    function it:getModID() return "GunsOfMarz" end
    function it:getMountOn() return javaList(r.mounts) end
    function it:isRanged() return true end
    function it:getName() return fullType end
    function it:getAllWeaponParts() return javaList({}) end
    function it:getModelWeaponPart()
        local models = {}; for _, name in ipairs(r.models) do models[#models+1] = {partType=name} end
        return javaList(models)
    end
    function it:getScriptItem()
        return { getScriptLines = function()
            local lines = {}
            for _, name in ipairs(r.models) do lines[#lines+1] = " ModelWeaponPart = "..name.." model self parent," end
            return javaList(lines)
        end }
    end
    return it
end
for _, r in pairs(installedRecords) do
    local record = r
    scripts[#scripts+1] = { getFullName = function() return record.fullType end,
        getModID = function() return "GunsOfMarz" end,
        getObsolete = function() return false end, isItemType = function(_, kind) return kind == record.type end }
end
function getScriptManager() return { getAllItems = function() return javaList(scripts) end } end
M.cache = nil
local m4 = instanceItem("MarzGuns.M4A1")
assert(M.supported(m4))
local c = M.candidates(m4)
for _, slot in ipairs({"Up","Down","Left","Right"}) do
    local e = assert(c["MarzGuns.Picatinny_Rail_" .. slot], "missing M4 rail " .. slot)
    assert(e.consume == "MarzGuns.Picatinny_Rail", "generic rail mapping")
end
local scan = { byType = { ["MarzGuns.Picatinny_Rail"] = {} } }
for i=1,4 do scan.byType["MarzGuns.Picatinny_Rail"][i] = { item = item("MarzGuns.Picatinny_Rail", i), key="floor" } end
local choice = { "MarzGuns.Picatinny_Rail_Up", "MarzGuns.Picatinny_Rail_Down", "MarzGuns.Picatinny_Rail_Left", "MarzGuns.Picatinny_Rail_Right" }
assert(#assert(P.solve(c, {}, M.availability(c, scan), choice)) == 4)
scan.byType["MarzGuns.Picatinny_Rail"][4] = nil
assert(not P.solve(c, {}, M.availability(c, scan), choice), "four rails need four objects")
for _, gun in ipairs({"MOSSBERG_590","BENELLI_M4"}) do
    local cat = M.candidates(instanceItem("MarzGuns."..gun))
    assert(cat["MarzGuns.Picatinny_Rail_Up"])
    assert(not cat["MarzGuns.Picatinny_Rail_Left"] and not cat["MarzGuns.Picatinny_Rail_Right"])
end
for gun, mount in pairs({M92FS="Beretta_Mount",M1911="Colt_Mount",DEAGLE="Heavy_Pistol_Rail"}) do
    local cat = M.candidates(instanceItem("MarzGuns."..gun))
    assert(cat["MarzGuns."..mount], "pistol mount "..gun)
    for otherGun, otherMount in pairs({M92FS="Beretta_Mount",M1911="Colt_Mount",DEAGLE="Heavy_Pistol_Rail"}) do
        if otherGun ~= gun then assert(not cat["MarzGuns."..otherMount], "wrong pistol mount") end
    end
end
-- Exercise the actual read-only GoM tool callback, including broken tools.
local tools = {}
local inv = { getFirstTagEvalRecurse = function(_, tag, predicate)
    local it = tools[tag]; if it and predicate(it) then return it end
end }
local player = { getInventory = function() return inv end }
local part = item("scope", 1, "Scope")
assert(not MarzGuns_AttachAndDetach.requiredTools(player, m4, part))
tools.screwdriver = { isBroken = function() return true end }
assert(not MarzGuns_AttachAndDetach.requiredTools(player, m4, part))
tools.screwdriver.isBroken = function() return false end
assert(MarzGuns_AttachAndDetach.requiredTools(player, m4, part))
part = item("barrel", 1, "Barrel")
assert(not MarzGuns_AttachAndDetach.requiredTools(player, m4, part))
tools.pipe_wrench = { isBroken = function() return false end }
assert(MarzGuns_AttachAndDetach.requiredTools(player, m4, part))
-- Current GoM ownership only; a third-party firearm in Base is not vanilla.
m4.getModID = function() return "OtherGunMod" end
assert(not M.supported(m4))
-- Vanilla is supported only under current GoM, including non-modelled upgrades.
local vanilla = instanceItem("MarzGuns.M4A1")
vanilla.getModID = function() return "pz-vanilla" end
vanilla.getFullType = function() return "Base.TestFirearm" end
vanilla.getScriptItem = function() return {getScriptLines=function() return javaList({
    "// ModelWeaponPart = Fake.Comment model self parent,",
    "/* ModelWeaponPart = Fake.Block model self parent, */"
}) end} end
assert(#M.keys(M.modelTypes(vanilla)) == 0, "comments are not declarations")
local vanillaPart = item("Base.TestScope", 5000, "Scope")
vanillaPart.getModID = function() return "pz-vanilla" end
vanillaPart.getMountOn = function() return javaList({"Base.TestFirearm"}) end
M.cache["Base.TestScope"] = vanillaPart
assert(M.supported(vanilla) and M.candidates(vanilla)["Base.TestScope"])
function getActivatedMods() return { contains = function() return false end } end
assert(not M.supported(vanilla), "vanilla-only installation disabled")
