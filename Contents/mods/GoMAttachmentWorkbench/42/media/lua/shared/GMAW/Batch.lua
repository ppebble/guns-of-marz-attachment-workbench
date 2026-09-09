local M = require "GMAW/Model"
local Required = require "WeaponSystems/Utils/RequiredAttachment"
local Underbarrel = require "WeaponSystems/Utils/Underbarrel"
local Railing = require "WeaponSystems/Utils/Railing"
local B = {}
local function depends(child, parent)
    if Required.RequiresParent(child, parent) then return true end
    for _, fullType in ipairs(Railing.AcceptedAccessories[parent] or {}) do
        if fullType == child then return true end
    end
    return false
end

function B.preflight(player, weapon, catalog, plan, removeSlot, toolsWillTransfer)
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return nil, "Special" end
    local installed, detach, replacing = M.installed(weapon), {}, {}
    if removeSlot then
        if not installed[removeSlot] then return nil, "Stale" end
        detach[removeSlot] = installed[removeSlot]
    end
    for _, step in ipairs(plan) do
        if step.old then detach[step.slot] = step.old; replacing[step.slot] = true end
        local source = step.source.item
        local part = source
        if source:getFullType() ~= step.fullType then part = instanceItem(step.fullType) end
        -- Tool transfers are queued before this action. Preserve native
        -- canAttach validation at execution time once they are in inventory.
        if not part or (not toolsWillTransfer and not part:canAttach(player, weapon)) then return nil, "Tools" end
        step.part = part
    end
    -- Temporarily remove installed descendants before replacing a mount.
    local changed = true
    while changed do
        changed = false
        for _, parent in pairs(detach) do
            for slot, child in pairs(installed) do
                if not detach[slot] and depends(child:getFullType(), parent:getFullType()) then
                    detach[slot], changed = child, true
                end
            end
        end
    end
    local detached, visiting, done = {}, {}, {}
    local function order(slot)
        if done[slot] then return true end
        if visiting[slot] then return false end
        visiting[slot] = true
        local parent = detach[slot]
        for _, cs in ipairs(M.keys(detach)) do
            if depends(detach[cs]:getFullType(), parent:getFullType()) and not order(cs) then return false end
        end
        visiting[slot], done[slot] = nil, true
        detached[#detached + 1] = { slot = slot, part = parent, replace = replacing[slot] }
        return true
    end
    for _, slot in ipairs(M.keys(detach)) do
        local part = detach[slot]
        if M.permanent(part) or not part:canDetach(player, weapon) then return nil, "Tools" end
        -- Stateful underbarrels can hold ammunition. Never bypass their refund workflow.
        if Underbarrel.UnderbarrelAttachments[part:getFullType()] then return nil, "Special" end
        if not removeSlot and not replacing[slot] and not toolsWillTransfer
            and not part:canAttach(player, weapon) then return nil, "Tools" end
        if not order(slot) then return nil, "Dependency" end
    end
    return { player = player, weapon = weapon, plan = plan, detached = detached }
end

-- Read-only preflight/order data. Native timed actions own all mutations.
return B
