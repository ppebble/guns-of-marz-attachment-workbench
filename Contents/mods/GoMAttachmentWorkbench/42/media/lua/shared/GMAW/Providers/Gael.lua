-- Exact-owner integration; Base is a script namespace, not an ownership test.
local G = {id="GaelGunStore_B42", attachmentSystem="gael"}
G.slots = {"Scope", "Canon", "RecoilPad", "Sling", "Stock", "Mount", "L_Scope",
    "Laser", "Light", "Grip", "Handguard", "Barrel_Shroud", "Misc", "Stool"}
-- Hide_Beam is created/removed by Gael's laser toggle, not player equipment.
-- Stateful launchers remain owned by Gael's native attachment UI.
function G.managed(part)
    local slot = part:getPartType()
    return slot ~= "Hide_Beam" and slot ~= "Clip" and slot ~= "AMMO"
        and slot ~= "Ammo" and slot ~= "Stool"
end
local deployedBipods = { ["Base.bipod_harris_open"]=true, ["Base.bipod_old_open"]=true,
    ["Base.bipod_simple_open"]=true, ["Base.scrap_bipod_open"]=true }
function G.selectable(part)
    return G.managed(part) and not deployedBipods[part:getFullType()]
end
function G.enabled() return getActivatedMods():contains(G.id) end
function G.owns(item)
    return item and item.getModID and item:getModID() == G.id
end
local function dependencies()
    return require "GGS_AttachmentDependencies"
end
local function installed(weapon, slot)
    local parts = weapon:getAllWeaponParts()
    for i=0,parts:size()-1 do
        local part = parts:get(i)
        if part:getPartType() == slot then return part end
    end
end
-- Gael's public native UI conflicts, also enforced on the server here.
local conflicts = {
    Mount={"L_Scope"}, Scope={"L_Scope"}, L_Scope={"Mount","Scope"},
    Stool={"Barrel_Shroud","Grip"}, Barrel_Shroud={"Stool"}, Grip={"Stool"},
}
local function conflictsFor(weapon, slot)
    if slot == "Laser" or slot == "Light" then
        local anim = weapon.getSwingAnim and weapon:getSwingAnim()
        if anim == "Handgun" or anim == "Pistol"
            or (weapon.isTwoHandWeapon and not weapon:isTwoHandWeapon()) then
            return {slot == "Laser" and "Light" or "Laser"}
        end
    end
    return conflicts[slot] or {}
end
local function mountsOn(part, weapon)
    local mounts = part:getMountOn()
    for i=0,mounts:size()-1 do
        if mounts:get(i) == weapon:getFullType() then return true end
    end
    return false
end
-- Build once per candidate request, not once per candidate. MountOn lists can
-- contain hundreds of weapon names and each access crosses the Lua/Java bridge.
-- This is request-local: native dependency data and weapon state remain fresh.
function G.prepareMetadata(weapon, catalog)
    local context = {api=dependencies(), unlocks={}, partsBySlot={}, metadata={}}
    for fullType, other in pairs(catalog) do
        if G.owns(other) and G.selectable(other) and mountsOn(other, weapon) then
            local otherSlot = other:getPartType()
            context.partsBySlot[otherSlot] = context.partsBySlot[otherSlot] or {}
            context.partsBySlot[otherSlot][fullType] = true
            for _, unlocked in ipairs(context.api.getProviderUnlocks(fullType) or {}) do
                context.unlocks[unlocked] = context.unlocks[unlocked] or {}
                context.unlocks[unlocked][fullType] = true
            end
        end
    end
    return context
end
function G.metadata(weapon, part, catalog, context)
    context = context or G.prepareMetadata(weapon, catalog)
    local slot = part:getPartType()
    local data = context.metadata[slot]
    if not data then
        data = {any={}, excludes={}}
        if context.api.isSlotDependent(weapon, slot) then
            data.any = context.unlocks[slot] or {}
        end
        for _, conflict in ipairs(conflictsFor(weapon, slot)) do
            for fullType in pairs(context.partsBySlot[conflict] or {}) do
                data.excludes[fullType] = true
            end
        end
        context.metadata[slot] = data
    end
    return {all={}, any=data.any, excludes=data.excludes, consume=part:getFullType()}
end
function G.canAttach(part, player, weapon)
    if not G.acceptsWeapon(weapon) or not G.owns(part) then return false end
    local slot = part:getPartType()
    -- Launchers retain their own ammunition state; leave these to Gael's UI.
    if not G.selectable(part) then return false end
    local api = dependencies()
    if not api or not api.isSlotUnlocked(weapon, slot) then return false end
    for _, other in ipairs(conflictsFor(weapon, slot)) do
        if installed(weapon, other) then return false end
    end
    return part:canAttach(player, weapon)
end
function G.removable(part, weapon)
    if not G.acceptsWeapon(weapon) or not G.owns(part) or not G.managed(part) then return false end
    local api = dependencies()
    if not api then return false end
    for _, slot in ipairs(api.getProviderUnlocks(part:getFullType()) or {}) do
        if installed(weapon, slot) then return false end
    end
    return true
end
function G.canDetach(part, player, weapon)
    return G.removable(part, weapon) and part:canDetach(player, weapon)
end
function G.register(adapters)
    G.acceptsWeapon = function(weapon)
        return adapters.weaponSystem(weapon) == G.attachmentSystem
    end
    local slots = {}
    for _, slot in ipairs(G.slots) do slots[slot] = true end
    adapters.registerWeapon("gael", {
        owner=G.id, requires={G.id}, attachmentSystem=G.attachmentSystem, slots=slots, mountOwners={[G.id]=true},
    })
    adapters.registerPart("gael", {
        owner=G.id, requires={G.id}, attachmentSystem=G.attachmentSystem, slots=slots,
        compatible=function(part, weapon) return G.acceptsWeapon(weapon) and G.selectable(part) end,
        canAttach=G.canAttach, canDetach=G.canDetach,
        canPlanAttach=function(part, player, weapon)
            return G.acceptsWeapon(weapon) and G.selectable(part) and part:canAttach(player, weapon)
        end,
        toolKey=function() return "Screwdriver" end,
        tools=function() return {{ItemTag.SCREWDRIVER}} end,
        action=function(player, weapon, part, removing)
            local framework = require "GMAW/Framework"
            framework.loadActions()
            if removing then return ISRemoveWeaponUpgrade:new(player, weapon, part:getPartType()) end
            return ISUpgradeWeapon:new(player, weapon, part)
        end,
    })
end
return G
