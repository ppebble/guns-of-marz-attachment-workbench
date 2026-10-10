-- Explicit opt-in weapon/part adapters. Synthetic fixtures only; never
-- substitute these for the installed Emre/Gunworks native action tests.
local M = require "GMAW/Model"
local A = require "GMAW/Adapters"
local T = require "GMAW/Attachments"
local Authority = require "GMAW/Authority"
local savedMods, savedManager = getActivatedMods, getScriptManager
local savedInstance, savedType, savedCatalog = instanceItem, ItemType, M.cache
local active = {}
function getActivatedMods()
    return { contains = function(_, id) return active[id] == true end }
end
local function enable(...)
    active = {}
    for _, name in ipairs({...}) do active[name] = true end
    M.cache = nil
end
local function firearm(owner, fullType, ranged)
    return {
        class = "HandWeapon",
        getModID = function() return owner end,
        getFullType = function() return fullType end,
        isRanged = function() return ranged ~= false end,
        getWeaponPart = function() return nil end,
    }
end
local function part(owner, fullType, slot, mountOn)
    return {
        getModID = function() return owner end,
        getFullType = function() return fullType end,
        getPartType = function() return slot end,
        getMountOn = function() return javaList(mountOn) end,
        isBroken = function() return false end,
        canAttach = function() return true end,
    }
end

-- These are representative actual bridge fullTypes and part slots.
local gom = firearm("GunsOfMarz", "MarzGuns.M4A1")
local legacy = firearm("MarzGuns", "MarzGuns.M4A1")
local vanilla = firearm("pz-vanilla", "Base.Pistol")
local emre = firearm("EmreFirearmsPack_B42", "ENF2.AR15")
local unmapped = firearm("EmreFirearmsPack_B42", "EFS.Glock17")
local stranger = firearm("OtherWeaponMod", "OtherWeaponMod.M16")
local forged = firearm("EmreFPGoMCompat", "ENF2.AR15")

ItemType = { WEAPON_PART = "weaponpart" }
local up = part("GunsOfMarz", "MarzGuns.Picatinny_Rail_Up",
    "RailUp", {"MarzGuns.M4A1", "ENF2.AR15"})
local scope = part("GunsOfMarz", "MarzGuns.M4_Exclusive_Scope",
    "Scope", {"MarzGuns.M4A1"})
local clip = part("GunsOfMarz", "MarzGuns.556Magazine",
    "Clip", {"EFS.Glock17"})
local emrePart = part("EmreFirearmsPack_B42", "ENF2.CustomPart",
    "Scope", {"ENF2.AR15"})
local parts = {
    [up:getFullType()] = up,
    [scope:getFullType()] = scope,
    [clip:getFullType()] = clip,
    [emrePart:getFullType()] = emrePart,
}
local scripts = {}
local function buildScripts()
    scripts = {}
    for fullType, it in pairs(parts) do
        local itemFullType, instance = fullType, it
        scripts[#scripts + 1] = {
            getModID = function() return instance:getModID() end,
            getFullName = function() return itemFullType end,
            getObsolete = function() return false end,
            isItemType = function(_, kind) return kind == ItemType.WEAPON_PART end,
        }
    end
end
buildScripts()
function getScriptManager() return {getAllItems = function() return javaList(scripts) end} end
function instanceItem(fullType) return parts[fullType] end

enable("GunsOfMarz")
assert(M.supported(gom) and M.supported(vanilla), "GoM and vanilla unchanged")
assert(not M.supported(emre) and not M.supported(stranger), "GoM-only cannot use foreign guns")

enable("GunsOfMarz", "EmreFirearmsPack_B42")
assert(not M.supported(emre), "Emre pack alone is insufficient")
enable("GunsOfMarz", "EmreFPGoMCompat")
assert(not M.supported(emre), "Emre bridge alone is insufficient")
enable("GunsOfMarz", "EmreFirearmsPack_B42", "EmreFPGoMCompat")
assert(M.enabled() and M.supported(emre), "complete bridge plus native GoM MountOn accepts Emre")
assert(M.supported(gom) and M.supported(vanilla), "GoM and vanilla retained with bridge")
assert(not M.owned(emre) and not M.supported(stranger) and not M.supported(forged),
    "never broaden existing part owner or arbitrary gun owners")
assert(not M.supported(unmapped), "unmapped additional Emre gun is not a fake compatibility grant")
assert(not M.supported(firearm("EmreFirearmsPack_B42", "ENF2.Axe", false)), "no melee weapons")
assert(not M.supported({class="WeaponPart", getModID=function() return "EmreFirearmsPack_B42" end,
    isRanged=function() return true end}), "no weapon parts as firearms")
local catalog = M.catalog()
assert(catalog[up:getFullType()] and catalog[scope:getFullType()] and catalog[clip:getFullType()])
assert(not catalog[emrePart:getFullType()], "Emre's own parts do not enter GoM catalog")
assert(M.candidates(emre)[up:getFullType()], "bridge-registered GoM rail visible")
assert(not M.candidates(emre)[scope:getFullType()] and not M.candidates(emre)[emrePart:getFullType()],
    "GoM-only and foreign-owner parts do not appear on Emre")
assert(M.candidates(gom)[up:getFullType()] and M.candidates(gom)[scope:getFullType()],
    "original GoM catalog remains unchanged")
assert(not M.supported(unmapped), "clip registration alone cannot enable unrelated part slots")

-- The authoritative server rejects unsupported weapons AND spoofed parts.
local inv = {getItemById = function(_, id)
    if id == 42 then return emre end
    if id == 43 then return scope end
end}
local player = {getInventory = function() return inv end}
enable("GunsOfMarz", "EmreFirearmsPack_B42")
local ok, reason = Authority.apply(player, {kind="detach", weaponID=42, slot="Scope"})
assert(not ok and reason == "Weapon", "bridge-missing server rejects Emre")
enable("GunsOfMarz", "EmreFirearmsPack_B42", "EmreFPGoMCompat")
ok, reason = Authority.apply(player, {kind="detach", weaponID=42, slot="Scope"})
assert(not ok and reason == "Detach", "server passes adapter gate then checks installed part")
ok, reason = Authority.apply(player, {
    kind="install", weaponID=42, slot="Scope", partID=43, fullType=scope:getFullType()})
assert(not ok and reason == "Part", "server blocks forged cross-weapon part even if client supplies IDs")

enable("MarzGuns", "EmreFirearmsPack_B42", "EmreFPGoMCompat")
assert(M.supported(legacy) and not M.supported(emre), "old GoM keeps current policy")
enable("GunsOfMarz", "MarzGuns", "EmreFirearmsPack_B42", "EmreFPGoMCompat")
assert(not M.supported(gom) and not M.supported(emre), "conflicting GoM variants still disabled")
enable("EmreFirearmsPack_B42", "EmreFPGoMCompat")
assert(not M.supported(emre), "Emre-GoM adapter still depends on actual GoM")

-- A second, unrelated provider proves that the registry is not hard-coded
-- to GoM/Emre. It can opt in ONLY with explicit native part handling.
local customGun = firearm("FutureWeaponPack", "FuturePack.ExperimentalRifle")
local customPart = part("FutureAttachments", "FutureAttachments.Scope", "Scope",
    {"FuturePack.ExperimentalRifle"})
enable("FutureWeaponPack", "FutureAttachments")
assert(not M.supported(customGun) and not T.owner(customPart),
    "unknown mods remain denied until an explicit adapter is registered")
local createdActions = 0
A.registerWeapon("test-future-weapon", {
    owner="FutureWeaponPack", requires={"FutureWeaponPack", "FutureAttachments"},
    mountOwners={FutureAttachments=true},
})
A.registerPart("test-future-parts", {
    owner="FutureAttachments", requires={"FutureAttachments"},
    compatible=function(p, w) return p:getFullType() == customPart:getFullType()
        and w:getFullType() == customGun:getFullType() end,
    canAttach=function(p, _, w) return w:getFullType() == customGun:getFullType() end,
    tools=function() return {} end,
    action=function(_, _, _, removing)
        createdActions = createdActions + 1
        return {isValid=function() return true end, complete=function() return true end,
            removing=removing}
    end,
})
parts[customPart:getFullType()] = customPart
buildScripts()
M.cache = nil
assert(M.enabled() and M.supported(customGun), "independent adapter opens a new weapon owner")
assert(M.catalog()[customPart:getFullType()], "explicit part adapter extends the catalog")
assert(M.candidates(customGun)[customPart:getFullType()], "native MountOn still controls candidate")
assert(T.owner(customPart) == "test-future-parts" and T.compatible(customPart, customGun))
assert(T.canAttach(customPart, player, customGun), "custom native validation reached")
assert(#T.tools(customPart, false) == 0)
local action = T.action(player, customGun, customPart, false)
assert(action:isValid() and action:complete() and createdActions == 1, "custom action route used")
local customInv = {
    getItemById=function(_, id)
        if id == 77 then return customGun end
        if id == 78 then return customPart end
    end,
}
local customPlayer = {getInventory=function() return customInv end}
local applied, nativePart, nativeKind = Authority.apply(customPlayer, {
    kind="install", weaponID=77, partID=78,
    slot="Scope", fullType=customPart:getFullType(),
})
assert(applied and nativePart == customPart and nativeKind == "native" and createdActions == 2,
    "server safely routes an explicitly registered non-GoM native part")
assert(not pcall(function() A.registerPart("invalid-action", {
    owner="UnknownParts", requires={"UnknownParts"},
}) end), "part owners require complete native callback contracts")
enable("GunsOfMarz")
assert(not M.supported(customGun) and not T.owner(customPart), "adapter disabled without dependencies")

getActivatedMods = savedMods
getScriptManager = savedManager
instanceItem = savedInstance
ItemType = savedType
M.cache = savedCatalog
print("weapon adapters: GoM regression, Emre native bridge, owner isolation, server gate, future extension")
