local M = require "GMAW/Model"
local P = {}

-- Pure dependency solver. Availability is fullType -> ordered source entries.
-- A cart has one explicit choice per slot; prerequisites never overwrite it.
function P.solve(catalog, installed, available, choices)
    local wanted, visiting, ordered, used = {}, {}, {}, {}
    local function sourceFor(fullType)
        for _, source in ipairs(available[fullType] or {}) do
            if not used[source.item:getID()] then return source end
        end
    end
    local function present(fullType)
        local entry = catalog[fullType]
        if entry and wanted[entry.slot] then return wanted[entry.slot] == fullType end
        for slot, part in pairs(installed) do
            if part:getFullType() == fullType and not wanted[slot] then return true end
        end
        return false
    end
    for _, fullType in ipairs(choices) do
        local c = catalog[fullType]
        if not c then return nil, "Unsupported" end
        if wanted[c.slot] and wanted[c.slot] ~= fullType then return nil, "Conflict" end
        wanted[c.slot] = fullType
    end
    local done = {}
    local function add(fullType)
        if done[fullType] then return true end
        local c = catalog[fullType]
        if not c then return false, "Dependency" end
        if visiting[fullType] then return false, "Dependency" end
        if wanted[c.slot] and wanted[c.slot] ~= fullType then return false, "Conflict" end
        local old = installed[c.slot]
        if old and old:getFullType() == fullType then done[fullType] = true; return true end
        local source = sourceFor(fullType)
        if not source then return false, "Missing" end
        used[source.item:getID()] = true
        visiting[fullType], wanted[c.slot] = true, fullType
        for _, parent in ipairs(M.keys(c.all)) do
            if not present(parent) or (catalog[parent] and wanted[catalog[parent].slot] == parent) then
                local ok, why = add(parent)
                if not ok then return false, why end
            end
        end
        local parents = M.keys(c.any)
        if #parents > 0 then
            local selected
            for _, parent in ipairs(parents) do if present(parent) then selected = parent; break end end
            if not selected then
                for _, parent in ipairs(parents) do
                    local pc = catalog[parent]
                    if pc and (not wanted[pc.slot] or wanted[pc.slot] == parent)
                        and sourceFor(parent) then selected = parent; break end
                end
            end
            if not selected then return false, "Dependency" end
            if catalog[selected] and (not present(selected) or wanted[catalog[selected].slot] == selected) then
                local ok, why = add(selected)
                if not ok then return false, why end
            end
        end
        visiting[fullType], done[fullType] = nil, true
        ordered[#ordered + 1] = { fullType = fullType, slot = c.slot,
            source = source, old = old }
        return true
    end
    local sorted = {}
    for _, fullType in pairs(wanted) do sorted[#sorted + 1] = fullType end
    table.sort(sorted)
    for _, fullType in ipairs(sorted) do
        local ok, why = add(fullType)
        if not ok then return nil, why end
    end
    -- Replacing a parent must not strand an existing child, even if not in cart.
    local final = {}
    for slot, part in pairs(installed) do final[slot] = part:getFullType() end
    for _, step in ipairs(ordered) do final[step.slot] = step.fullType end
    local types = {}
    for _, fullType in pairs(final) do types[fullType] = true end
    for _, fullType in pairs(final) do
        local c = catalog[fullType]
        if c then
            for other in pairs(c.excludes or {}) do if types[other] then return nil, "Conflict" end end
            for parent in pairs(c.all) do if not types[parent] then return nil, "Dependency" end end
            if #M.keys(c.any) > 0 then
                local found = false
                for parent in pairs(c.any) do if types[parent] then found = true end end
                if not found then return nil, "Dependency" end
            end
        end
    end
    return ordered
end

function P.signature(plan)
    local out = {}
    for _, s in ipairs(plan) do
        out[#out + 1] = s.fullType .. ":" .. tostring(s.source.item:getID()) .. ":" .. s.source.key
    end
    return table.concat(out, "|")
end

return P
