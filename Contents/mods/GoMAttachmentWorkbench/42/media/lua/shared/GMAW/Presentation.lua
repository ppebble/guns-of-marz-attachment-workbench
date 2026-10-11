local M = require "GMAW/Model"
local P = require "GMAW/Planner"
local S = require "GMAW/Sources"
local T = require "GMAW/Attachments"
local V = {}

function V.choices(choices, catalog, extra)
    local out = {}
    for slot, fullType in pairs(choices) do
        if not extra or catalog[extra].slot ~= slot then out[#out + 1] = fullType end
    end
    if extra then out[#out + 1] = extra end
    table.sort(out)
    return out
end

-- Rendering data only. Installed, queued, and merely compatible are distinct.
function V.build(catalog, installed, available, choices, player, weapon, scan)
    local view = { slots = {}, bySlot = {} }
    local onlyOwned = SandboxVars and SandboxVars.GoMAttachmentWorkbench
        and SandboxVars.GoMAttachmentWorkbench.ShowOnlyOwnedParts == true
    view.plan, view.reason = P.solve(catalog, installed, available, V.choices(choices, catalog))
    local cartPlan, cartReason = view.plan, view.reason
    if weapon and not M.actionSafe(weapon) then view.plan, view.reason = nil, "NativeConflict" end
    local queued = {}
    for _, step in ipairs(view.plan or {}) do queued[step.slot] = step.fullType end
    local candidates = {}
    for fullType, c in pairs(catalog) do
        candidates[c.slot] = candidates[c.slot] or {}
        candidates[c.slot][fullType] = c
    end
    for _, slot in ipairs(M.slots) do
        local card = { slot = slot, installed = installed[slot], options = {} }
        local queuedType = queued[slot]
        if queuedType then card.queued = catalog[queuedType].part; card.automatic = choices[slot] == nil end
        for fullType, c in pairs(candidates[slot] or {}) do
            local current = card.installed and card.installed:getFullType() == fullType
            local owned = false
            if onlyOwned then
                -- Availability already maps generic rails to their directional
                -- outcomes; carried bags retain the Player source kind.
                for _, source in ipairs(available[fullType] or {}) do
                    if source.kind == "Player" then owned = true; break end
                end
            end
            if (not onlyOwned or owned or current
                or choices[slot] == fullType or queuedType == fullType) then
                local plan, reason
                if choices[slot] == fullType then
                    plan, reason = cartPlan, cartReason
                else
                    plan, reason = P.solve(catalog, installed, available, V.choices(choices, catalog, fullType))
                end
                local checked, attachable, nearbyTools = true, true, false
                -- Rejected plans already determine the status and its reason.
                -- Native callbacks and tool scans add no preview information.
                if plan then
                    checked, attachable = pcall(T.canPlanAttach, c.part, player, weapon)
                    if checked and not attachable and scan then
                        local groups = M.toolGroups(c.slot, c.part)
                        nearbyTools = #groups > 0 and S.hasWorkingGroups(scan, groups)
                    end
                end
                -- canAttach checks GoM tools in the player inventory. A matching
                -- nearby tool is queued first, so do not grey this option early.
                local waitingForTransfer = checked and not attachable and nearbyTools
                local quantity = #(available[fullType] or {})
                card.options[#card.options + 1] = { fullType = fullType, item = c.part,
                    quantity = quantity, current = current, queued = choices[slot] == fullType,
                    dim = not current and (quantity == 0 or not plan or not checked
                        or (not attachable and not waitingForTransfer)),
                    reason = reason or ((not checked or (not attachable and not waitingForTransfer)) and "Tools" or nil) }
            end
        end
        table.sort(card.options, function(a, b)
            if (a.quantity > 0) ~= (b.quantity > 0) then return a.quantity > 0 end
            local an, bn = a.item:getName(), b.item:getName()
            if an ~= bn then return an < bn end
            return a.fullType < b.fullType
        end)
        -- Owned-only filters purchasable/available choices, not the weapon's
        -- physical attachment positions. Keep the diagram stable as stock changes.
        if candidates[slot] or card.installed then
            view.slots[#view.slots + 1] = card; view.bySlot[slot] = card
        end
    end
    return view
end

return V
