local Framework = require "GMAW/Framework"
local Permanent = Framework.Permanent
local GoM = require "GMAW/Providers/GoM"
local Gael = require "GMAW/Providers/Gael"
local Attachments = require "GMAW/Attachments"
local Adapters = require "GMAW/Adapters"
local M = {}

-- Player-facing order: attachments first; prerequisite rails/mounts are last.
M.slots = { "Scope", "LaserRifle", "LightRifle", "Foregrip", "Bipod", "Underbarrel",
    "Canon", "Suppressor", "Barrel", "Shellholder", "Stock", "Sling", "RecoilPad", "RailUp",
    "RailDown", "RailLeft", "RailRight", "CanonMount",
    "Mount", "L_Scope", "Laser", "Light", "Grip", "Handguard",
    "Barrel_Shroud", "Misc", "Stool" }

function M.enabled()
    return GoM.enabled() or Adapters.anyWeaponEnabled()
end
M.owned = GoM.owned
M.coreSupported = GoM.coreSupported
function M.actionSafe(weapon)
    return not getActivatedMods():contains("GaelGunStore_B42")
        or Adapters.weaponSystem(weapon) == Gael.attachmentSystem
end
function M.partAllowed(weapon, part)
    return Attachments.sameProvider(part, weapon)
end

local providers = {[GoM.attachmentSystem]=GoM, [Gael.attachmentSystem]=Gael}
local slotSets = {}
for id, provider in pairs(providers) do
    local slots = {}
    for _, slot in ipairs(provider.slots) do slots[slot] = true end
    slotSets[id] = slots
end

function M.providerFor(item)
    return providers[Adapters.weaponSystem(item)]
end

function M.adapterFor(item)
    if not item or not instanceof(item, "HandWeapon") or not item:isRanged() then return nil end
    if not Adapters.hasActiveWeaponOwner(item) then return nil end
    local system = Adapters.weaponSystem(item)
    if not providers[system] then return nil end
    return Adapters.weapon(item, M.catalog(), slotSets[system])
end

function M.supported(item)
    if not item or not instanceof(item, "HandWeapon") or not item:isRanged() then return false end
    return M.coreSupported(item) or M.adapterFor(item) ~= nil
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
            if part and (M.owned(part) or Attachments.owner(part))
                and (not Gael.owns(part) or Gael.selectable(part))
                and (Gael.owns(part) or not Permanent.IsPermanent(part:getFullType())) then
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

local function eligible(weapon, part, slots)
    if not slots[part:getPartType()] or not Attachments.compatible(part, weapon) then return false end
    -- Optional suppressors own their caliber-aware mount contract.
    if Attachments.owner(part) == "SimpleSuppressors" then return true end
    local mounts = part:getMountOn()
    for i=0,mounts:size()-1 do
        if mounts:get(i) == weapon:getFullType() then return true end
    end
    return false
end

-- Authority needs membership for the requested part, not the entire preview
-- dependency graph. Native attach checks still validate the live weapon later.
function M.isCandidate(weapon, fullType)
    local provider = M.providerFor(weapon)
    if not provider then return false end
    local part = M.catalog()[fullType]
    return part ~= nil and eligible(weapon, part, slotSets[provider.attachmentSystem])
end

function M.canOpen(weapon)
    if not M.supported(weapon) then return false end
    local provider = M.providerFor(weapon)
    if not provider then return false end
    local slots, catalog = slotSets[provider.attachmentSystem], M.catalog()
    for _, part in pairs(catalog) do
        if eligible(weapon, part, slots) then return true end
    end
    -- Installed known parts can still be removed after a mount mapping changes.
    -- Tool availability and carried stock must not hide the nearby-source UI.
    for _, part in pairs(M.installed(weapon)) do
        if catalog[part:getFullType()] and slots[part:getPartType()]
            and Attachments.sameProvider(part, weapon)
            and provider.removable(part, weapon) then return true end
    end
    return false
end

function M.candidates(weapon)
    local out, provider = {}, M.providerFor(weapon)
    if not provider then return out end
    local slots, catalog = slotSets[provider.attachmentSystem], M.catalog()
    local context = provider.prepareMetadata and provider.prepareMetadata(weapon, catalog)
    for fullType, part in pairs(catalog) do
        if eligible(weapon, part, slots) then
            local entry = provider.metadata(weapon, part, catalog, context)
            entry.part, entry.slot = part, part:getPartType()
            out[fullType] = entry
        end
    end
    return out
end

function M.availability(catalog, scan)
    local out = {}
    for fullType, c in pairs(catalog) do
        local sources = {}
        -- Detached directional rails are already the outcome item. Prefer them
        -- so shared generic kits remain available for the other directions.
        for _, source in ipairs(scan.byType[fullType] or {}) do sources[#sources + 1] = source end
        if c.consume and c.consume ~= fullType then
            for _, source in ipairs(scan.byType[c.consume] or {}) do sources[#sources + 1] = source end
        end
        out[fullType] = sources
    end
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
    return GoM.toolGroups(slot)
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
    return not Gael.owns(part) and Permanent.IsPermanent(part:getFullType())
end

function M.toolKey(part)
    local optional = Attachments.tools(part, false)
    if optional then return #optional == 0 and "NoTools" or "Screwdriver" end
    return GoM.toolKey(part)
end

return M
