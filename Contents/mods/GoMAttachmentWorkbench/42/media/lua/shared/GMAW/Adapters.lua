-- Optional integrations register explicit weapon and part capabilities.
-- No dependency becomes mandatory simply because an adapter is declared.
-- Keep this module shared: client UI and multiplayer authority must agree.
local A = {slots={}, revision=0}
local GoM = require "GMAW/Providers/GoM"
local weapons, parts = {}, {}
local providers, slotSets, knownSlots = {}, {}, {}

-- Shared startup contract: registering a system does not admit any item owner.
-- Weapon and part adapters still supply activation, MountOn and native actions.
function A.registerProvider(provider)
    assert(type(provider) == "table" and type(provider.attachmentSystem) == "string"
        and provider.attachmentSystem ~= "" and type(provider.slots) == "table"
        and #provider.slots > 0 and type(provider.metadata) == "function"
        and type(provider.removable) == "function", "provider requires system, slots, metadata and removal policy")
    local id, slots = provider.attachmentSystem, {}
    assert(not providers[id], "duplicate attachment system: " .. id)
    for _, slot in ipairs(provider.slots) do
        assert(type(slot) == "string" and slot ~= "" and not slots[slot], "invalid or duplicate provider slot")
        slots[slot] = true
    end
    for _, callback in ipairs({"prepareMetadata", "selectable", "permanent", "depends", "toolKey"}) do
        assert(provider[callback] == nil or type(provider[callback]) == "function", "invalid provider callback: " .. callback)
    end
    providers[id], slotSets[id] = provider, slots
    for _, slot in ipairs(provider.slots) do
        if not knownSlots[slot] then
            knownSlots[slot] = true
            A.slots[#A.slots + 1] = slot
        end
    end
    A.revision = A.revision + 1
end

function A.provider(system) return providers[system] end
function A.slotSet(system) return slotSets[system] end

local function active(spec, mods)
    for _, id in ipairs(spec.requires or {}) do
        if not mods:contains(id) then return false end
    end
    for _, id in ipairs(spec.excludes or {}) do
        if mods:contains(id) then return false end
    end
    return true
end

local function unique(registry, id)
    assert(type(id) == "string" and id ~= "", "adapter ID is required")
    for _, adapter in ipairs(registry) do
        assert(adapter.id ~= id, "duplicate adapter: " .. id)
    end
end

function A.registerWeapon(id, spec)
    unique(weapons, id)
    assert(type(spec) == "table" and type(spec.owner) == "string"
        and spec.owner ~= "" and type(spec.requires) == "table",
        "weapon adapters require an exact item owner and activation conditions")
    assert(type(spec.matches) == "function" or type(spec.mountOwners) == "table",
        "weapon adapters must constrain their eligible firearms")
    weapons[#weapons + 1] = {
        id = id, owner = spec.owner, requires = spec.requires,
        attachmentSystem = spec.attachmentSystem or "gom", slots = spec.slots,
        excludes = spec.excludes, mountOwners = spec.mountOwners,
        matches = spec.matches,
    }
    A.revision = A.revision + 1
end

-- Parts from third-party frameworks require explicit native actions and
-- validation. Merely activating a weapon adapter never imports its parts.
function A.registerPart(id, spec)
    unique(parts, id)
    assert(type(spec) == "table" and type(spec.owner) == "string"
        and spec.owner ~= "" and type(spec.requires) == "table"
        and type(spec.compatible) == "function"
        and type(spec.canAttach) == "function"
        and type(spec.tools) == "function"
        and type(spec.action) == "function",
        "part adapters must provide compatibility, tools and native completion")
    for _, callback in ipairs({"canPlanAttach", "canDetach", "toolKey"}) do
        assert(spec[callback] == nil or type(spec[callback]) == "function", "invalid part callback: " .. callback)
    end
    parts[#parts + 1] = {
        id = id, owner = spec.owner, requires = spec.requires,
        attachmentSystem = spec.attachmentSystem or "gom",
        excludes = spec.excludes, compatible = spec.compatible,
        canAttach = spec.canAttach, canDetach = spec.canDetach, tools = spec.tools, action = spec.action,
        canPlanAttach = spec.canPlanAttach, toolKey = spec.toolKey,
    }
    A.revision = A.revision + 1
end

function A.hasActiveWeaponOwner(item)
    if not item or not item.getModID then return false end
    local owner, mods = item:getModID(), getActivatedMods()
    for _, adapter in ipairs(weapons) do
        if owner == adapter.owner and active(adapter, mods) then return true end
    end
    return false
end

function A.part(part)
    if not part or not part.getModID then return nil end
    local owner, mods = part:getModID(), getActivatedMods()
    for _, adapter in ipairs(parts) do
        if owner == adapter.owner and active(adapter, mods) then return adapter end
    end
end

function A.anyWeaponEnabled()
    local mods = getActivatedMods()
    for _, adapter in ipairs(weapons) do
        if active(adapter, mods) then return true end
    end
    return false
end

local function hasRegisteredMount(weapon, catalog, owners, slots)
    if not catalog then return false end
    local fullType = weapon:getFullType()
    for _, part in pairs(catalog) do
        if owners[part:getModID()] and (not slots or slots[part:getPartType()]) and part.getMountOn then
            local mounts = part:getMountOn()
            if mounts then
                for i = 0, mounts:size() - 1 do
                    if mounts:get(i) == fullType then return true end
                end
            end
        end
    end
    return false
end

-- No global third-party gun whitelist: activation + exact owner + an
-- upstream registration (if specified) are all required on BOTH endpoints.
function A.weapon(weapon, catalog, slots)
    if not weapon or not weapon.getModID then return nil end
    local owner, mods = weapon:getModID(), getActivatedMods()
    for _, adapter in ipairs(weapons) do
        if owner == adapter.owner and active(adapter, mods)
            and (not adapter.matches or adapter.matches(weapon))
            and (not adapter.mountOwners or hasRegisteredMount(weapon, catalog, adapter.mountOwners, adapter.slots or slots)) then
            return adapter
        end
    end
end

-- Routing identifies an attachment system; weapon admission still checks native
-- MountOn through A.weapon. An unknown firearm owner receives no default.
function A.weaponSystem(weapon)
    if not weapon or not weapon.getModID then return nil end
    if GoM.coreSupported(weapon) then return GoM.attachmentSystem end
    local owner, mods = weapon:getModID(), getActivatedMods()
    for _, adapter in ipairs(weapons) do
        if owner == adapter.owner and active(adapter, mods)
            and (not adapter.matches or adapter.matches(weapon)) then
            return adapter.attachmentSystem
        end
    end
end

A.registerProvider(GoM)
GoM.register(A)

local Gael = require "GMAW/Providers/Gael"
A.registerProvider(Gael)
Gael.register(A)

return A
