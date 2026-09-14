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
    view.plan, view.reason = P.solve(catalog, installed, available, V.choices(choices, catalog))
    local queued = {}
    for _, step in ipairs(view.plan or {}) do queued[step.slot] = step.fullType end
    for _, slot in ipairs(M.slots) do
        local card = { slot = slot, installed = installed[slot], options = {} }
        local queuedType = queued[slot]
        if queuedType then card.queued = catalog[queuedType].part; card.automatic = choices[slot] == nil end
        for fullType, c in pairs(catalog) do
            if c.slot == slot then
                local plan, reason = P.solve(catalog, installed, available, V.choices(choices, catalog, fullType))
                local checked, attachable = pcall(T.canAttach, c.part, player, weapon)
                local groups = M.toolGroups(c.slot, c.part)
                local nearbyTools = #groups > 0 and scan and S.hasWorkingGroups(scan, groups)
                -- canAttach checks GoM tools in the player inventory. A matching
                -- nearby tool is queued first, so do not grey this option early.
                local waitingForTransfer = checked and not attachable and nearbyTools
                local current = card.installed and card.installed:getFullType() == fullType
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
        -- Unsupported slots are omitted, per the revised crafting-style layout.
        if #card.options > 0 or card.installed then
            view.slots[#view.slots + 1] = card; view.bySlot[slot] = card
        end
    end
    return view
end

return V
