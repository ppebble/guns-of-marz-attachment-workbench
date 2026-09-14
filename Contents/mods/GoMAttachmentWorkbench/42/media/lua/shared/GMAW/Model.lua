local Required = require "WeaponSystems/Utils/RequiredAttachment"
local Permanent = require "WeaponSystems/Utils/PreventRemovals"
local Universal = require "WeaponSystems/Utils/UniversalAttachment"
local Exclusives = require "WeaponSystems/Utils/UpgradeExclusives"
local Attachments = require "GMAW/Attachments"
local M = {}

-- Player-facing order: attachments first; prerequisite rails/mounts are last.
M.slots = { "Scope", "LaserRifle", "LightRifle", "Foregrip", "Bipod", "Underbarrel",
    "Canon", "Suppressor", "Barrel", "Shellholder", "Stock", "Sling", "RecoilPad", "RailUp",
    "RailDown", "RailLeft", "RailRight", "CanonMount" }

function M.enabled()
    local mods = getActivatedMods()
    return mods:contains("GunsOfMarz") ~= mods:contains("MarzGuns")
end

function M.owned(item)
    local id = item:getModID()
    return id == "GunsOfMarz" or id == "MarzGuns" or id == "pz-vanilla"
end

-- Simple Suppressors re-declares these vanilla scripts for render mappings,
-- changing their reported owner. Do not admit arbitrary Base/addon firearms.
local simpleVanilla = {
    ["Base.Shotgun"]=true, ["Base.JS3T_Shotgun"]=true,
    ["Base.AssaultRifle"]=true, ["Base.VarmintRifle"]=true, ["Base.JS14_Rifle"]=true,
    ["Base.Pistol"]=true, ["Base.Pistol2"]=true, ["Base.Pistol3"]=true,
    ["Base.TrapperCarbine"]=true, ["Base.L92_Carbine"]=true, ["Base.L94_Rifle"]=true,
    ["Base.AssaultRifle2"]=true, ["Base.HuntingRifle"]=true, ["Base.MSR7T_Rifle"]=true,
}

function M.supported(item)
    if not M.enabled() or not item or not instanceof(item, "HandWeapon") or not item:isRanged() then return false end
    return M.owned(item) or (item:getModID() == "SimpleSuppressors"
        and getActivatedMods():contains("SimpleSuppressors") and simpleVanilla[item:getFullType()] == true)
end

function M.keys(t)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = k end
    table.sort(out)
    return out
end

function M.installed(weapon)
    local out = {}
    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        out[part:getPartType()] = part
    end
    return out
end

function M.fingerprint(weapon)
    local state, out = M.installed(weapon), {}
    for _, slot in ipairs(M.keys(state)) do
        local p = state[slot]
        out[#out + 1] = slot .. ":" .. tostring(p:getID()) .. ":" .. p:getFullType()
    end
    return table.concat(out, "|")
end

-- No weapon creation: OnCreate on upstream weapons can randomize their contents.
-- Only WeaponPart definitions are instantiated, once per session. Optional
-- Simple Suppressors uses OnCreate to populate the instance's MountOn list.
function M.catalog()
    if M.cache then return M.cache end
    local out = {}
    local scripts = getScriptManager():getAllItems()
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        if (M.owned(script) or Attachments.owner(script)) and script:isItemType(ItemType.WEAPON_PART) and not script:getObsolete() then
            local part = instanceItem(script:getFullName())
            if part and (M.owned(part) or Attachments.owner(part)) and not Permanent.IsPermanent(part:getFullType()) then
                out[part:getFullType()] = part
            end
        end
    end
    M.cache = out
    return out
end

-- B42.20.4 ModelWeaponPart fields have no Lua getters; reflection is debug-only.
-- Read the engine's loaded script declarations instead. No disk paths or matrix.
function M.modelTypes(weapon)
    local lines, body = weapon:getScriptItem():getScriptLines(), {}
    for i = 0, lines:size() - 1 do body[#body + 1] = lines:get(i) end
    local text = table.concat(body, "\n"):gsub("/%*.-%*/", ""):gsub("//[^\n]*", "")
    local allowed = {}
    for fullType in text:gmatch("ModelWeaponPart%s*=%s*([^%s,]+)") do allowed[fullType] = true end
    return allowed
end

function M.candidates(weapon)
    local out, slots = {}, {}
    for _, slot in ipairs(M.slots) do slots[slot] = true end
    for fullType, part in pairs(M.catalog()) do
        local mounts, mountOK = part:getMountOn(), false
        for i = 0, mounts:size() - 1 do
            if mounts:get(i) == weapon:getFullType() then mountOK = true end
        end
        -- MountOn is the native compatibility contract used by the vanilla
        -- upgrade menu. ModelWeaponPart is visual metadata only: filtering by
        -- it hid valid left/right/down rails and valid sights on GoM weapons.
        if slots[part:getPartType()] and Attachments.compatible(part, weapon)
            and (mountOK or Attachments.owner(part) == "SimpleSuppressors") then
            out[fullType] = { part = part, slot = part:getPartType(),
                all = Required.Dependencies[fullType] or {},
                any = Required.AnyDependencies[fullType] or {},
                excludes = Exclusives.Exclusives[fullType] or {},
                consume = Universal.GetGenericItemTypeForOutcome(weapon, fullType) or fullType }
        end
    end
    return out
end

function M.availability(catalog, scan)
    local out = {}
    for fullType, c in pairs(catalog) do out[fullType] = scan.byType[c.consume] or {} end
    return out
end

-- Mounts are pinned in the workbench so selecting a dependent sight/light
-- never requires scrolling through the whole part catalog first.
-- GoM's tool mapping, expressed as alternative tag groups. Shared by the
-- preview and native transfer scheduler so nearby-tool availability agrees.
function M.toolGroups(slot, part, removing)
    if not ItemTag then return {} end
    local optional = Attachments.tools(part, removing)
    if optional then return optional end
    -- The shipped Old Version uses ItemCodeOnTest.hasScrewdriver, not the
    -- current GoM slot-specific wrench / screwdriver callback.
    if getActivatedMods():contains("MarzGuns") then return {{ItemTag.SCREWDRIVER}} end
    if slot == "Foregrip" then return {} end
    if slot == "CanonMount" or slot == "Canon" then
        return {{ItemTag.WRENCH, ItemTag.PIPE_WRENCH}}
    end
    if slot == "Barrel" then
        return {{ItemTag.SCREWDRIVER}, {ItemTag.WRENCH, ItemTag.PIPE_WRENCH}}
    end
    local screwdriverSlots = {Scope=true, RailUp=true, RailDown=true, RailRight=true,
        RailLeft=true, Bipod=true, Shellholder=true, Stock=true, Underbarrel=true,
        Sling=true, LaserRifle=true, LightRifle=true}
    return screwdriverSlots[slot] and {{ItemTag.SCREWDRIVER}} or {}
end

function M.isMountCandidate(catalog, fullType)
    local entry = catalog[fullType]
    if not entry then return false end
    if entry.slot == "CanonMount" or entry.slot:match("^Rail") then return true end
    for _, candidate in pairs(catalog) do
        if candidate.all[fullType] or candidate.any[fullType] then return true end
    end
    return false
end

function M.permanent(part)
    return Permanent.IsPermanent(part:getFullType())
end

function M.toolKey(part)
    local optional = Attachments.tools(part, false)
    if optional then return #optional == 0 and "NoTools" or "Screwdriver" end
    if part:getModID() == "MarzGuns" then return "Screwdriver" end
    if part:getModID() ~= "GunsOfMarz" then return "Tools" end
    local slot = part:getPartType()
    if slot == "Barrel" then return "BothTools" end
    if slot == "Canon" or slot == "CanonMount" then return "Wrench" end
    if slot == "Foregrip" then return "NoTools" end
    return "Screwdriver"
end

return M
