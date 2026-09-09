require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISInventoryPage"
require "TimedActions/ISInventoryTransferUtil"
require "WeaponSystems/Hooks/WeaponUpgradeHooks"
require "MarzWeapons/ISUI/RequiredToolVisualEquipt"
local M = require "GMAW/Model"
local P = require "GMAW/Planner"
local S = require "GMAW/Sources"
local B = require "GMAW/Batch"
local Universal = require "WeaponSystems/Utils/UniversalAttachment"
local Required = require "WeaponSystems/Utils/RequiredAttachment"
local Exclusives = require "WeaponSystems/Utils/UpgradeExclusives"
local A = { active = {}, results = {} }

local function collectTools(scan, requested, slot)
    for _, tags in ipairs(M.toolGroups(slot)) do
        local source = S.firstWorkingTag(scan, tags)
        if not source then return nil end
        requested[source.item:getID()] = source
    end
    return true
end

local function hasEntries(items)
    for _ in pairs(items) do return true end
    return false
end

-- Native helpers may enqueue equips as well as the actual upgrade. Track only
-- newly added actions; never clear/replace unrelated player work.
local function issueAuthority(batch, op)
    if not (isClient and isClient() and sendClientCommand) then return end
    sendClientCommand(batch.player, "GMAW", "apply", {
        kind = op.kind,
        weaponID = batch.weaponID,
        partID = op.id,
        slot = op.slot,
        fullType = op.fullType,
        generic = op.generic and true or false,
    })
end

-- Keep the exact vanilla actions for movement, equipment and timing. In
-- multiplayer their local completion is suppressed: the server receives the
-- completed operation and becomes the sole owner of attachment mutation.
local function enqueue(batch, callback, authority)
    local queue = ISTimedActionQueue.getTimedActionQueue(batch.player).queue
    local before = {}
    for _, action in ipairs(queue) do before[action] = true end
    callback()
    for _, action in ipairs(queue) do
        if not before[action] then
            batch.issued = true
            batch.handles[action] = true
            local ownsMutation = authority and authority.matches(action)
            if ownsMutation and isClient and isClient() then
                action.complete = function() return true end
            end
            local perform, stop, cancel = action.perform, action.stop, action.forceCancel
            action.perform = function(self, ...)
                if perform then perform(self, ...) end
                if ownsMutation then issueAuthority(batch, authority) end
                batch.handles[self] = "completed"
            end
            action.stop = function(self, ...)
                batch.cancelled = true
                if stop then return stop(self, ...) end
            end
            action.forceCancel = function(self, ...)
                batch.cancelled = true
                if cancel then return cancel(self, ...) end
            end
        end
    end
end

function A.busy(player)
    return A.active[player] ~= nil
end

local function finished(player, op, weapon)
    if not op then return true end
    if op.kind == "transfer" then return player:getInventory():containsID(op.id) end
    local part = weapon:getWeaponPart(op.slot)
    if op.kind == "detach" then return part == nil end
    return part and part:getFullType() == op.fullType
        and (op.generic or part:getID() == op.id)
end

function A.advance(player, batch)
    if batch.error or player:isDead() then return end
    local inv = player:getInventory()
    local weapon = inv:getItemById(batch.weaponID)
    if not finished(player, batch.previous, weapon or batch.weapon) then batch.error = "Stopped"; return end
    local op = batch.operations[batch.index]
    if not op then return end
    print("[GMAW] queue " .. op.kind .. " weapon=" .. tostring(batch.weaponID)
        .. " slot=" .. tostring(op.slot) .. " item=" .. tostring(op.fullType or op.id))
    if op.kind == "transfer" then
        local source = S.scan(player).byID[op.id]
        if not source or source.key ~= op.key then batch.error = "Stale"; return end
        if source.world then
            -- Populate the vanilla floor view; it supplies the source container
            -- to the native transfer action without moving the world item.
            local loot = getPlayerLoot(player:getPlayerNum())
            if loot then loot:refreshBackpacks() end
        end
        local container = source.item:getContainer()
        if not container then batch.error = "Stale"; return end
        enqueue(batch, function()
            ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, source.item, container, inv))
        end)
    else
        if not weapon or not M.supported(weapon) then batch.error = "Stale"; return end
        if not batch.startedAssembly and M.fingerprint(weapon) ~= batch.expected then batch.error = "Stale"; return end
        batch.startedAssembly = true
        if op.kind == "detach" then
            local part = weapon:getWeaponPart(op.slot)
            if not part or part:getID() ~= op.id or not part:canDetach(player, weapon)
                or M.permanent(part) or Required.IsRemovalBlocked(weapon, part:getFullType()) then
                batch.error = "Stopped"; return
            end
            enqueue(batch, function() ISInventoryPaneContextMenu.onRemoveUpgradeWeapon(weapon, part, player) end, {
                kind = "detach", id = op.id, slot = op.slot,
                matches = function(action) return action.weapon == weapon and action.partType == op.slot end,
            })
        else
            local part = op.refundType and inv:getFirstTypeRecurse(op.refundType) or inv:getItemById(op.id)
            if not part or part:isBroken() or weapon:getWeaponPart(op.slot)
                or Required.IsInstallationBlocked(weapon, op.fullType)
                or Exclusives.IsBlockedByExclusive(weapon, op.fullType) then batch.error = "Stopped"; return end
            if op.generic then
                if not Universal.CanInstallOutcome(weapon, op.fullType, player) then batch.error = "Tools"; return end
                enqueue(batch, function()
                    ISInventoryPaneContextMenu.transferIfNeeded(player, part)
                    ISInventoryPaneContextMenu.equipWeapon(part, false, false, player:getPlayerNum())
                    local tool = MarzGuns_AttachAndDetach.getPrimaryTool(player, op.slot)
                    if tool then ISInventoryPaneContextMenu.equipWeapon(tool, true, false, player:getPlayerNum()) end
                    -- Gunworks extends the native constructor with the outcome.
                    ISTimedActionQueue.add(ISUpgradeWeapon:new(player, weapon, part, op.fullType))
                end, {
                    kind = "install", id = op.id, slot = op.slot, fullType = op.fullType, generic = true,
                    matches = function(action) return action.weapon == weapon and action.part == part end,
                })
            else
                if not part:canAttach(player, weapon) then batch.error = "Tools"; return end
                enqueue(batch, function() ISInventoryPaneContextMenu.onUpgradeWeapon(weapon, part, player) end, {
                    kind = "install", id = op.id, slot = op.slot, fullType = op.fullType,
                    matches = function(action) return action.weapon == weapon and action.part == part end,
                })
            end
        end
    end
    batch.previous, batch.index = op, batch.index + 1

end

-- Runs independently of any window. Never recreate work after native cancellation.
local function settle(player, batch, code)
    A.active[player], A.results[player] = nil, code
    print("[GMAW] " .. code .. " weapon=" .. tostring(batch.weaponID)
        .. " operation=" .. tostring(batch.index - 1) .. "/" .. tostring(#batch.operations))
end

function A.tick()
    for player, batch in pairs(A.active) do
        local queue = ISTimedActionQueue.getTimedActionQueue(player).queue
        local waiting, interrupted = false, batch.cancelled or player:isDead() or player:pressedCancelAction()
        for action, state in pairs(batch.handles) do
            if ISTimedActionQueue.hasAction(action) then waiting = true
            elseif state ~= "completed" then interrupted = true end
        end
        if interrupted or batch.error then
            settle(player, batch, batch.error or "Stopped")
        elseif not waiting and #queue == 0 then
            local weapon = player:getInventory():getItemById(batch.weaponID)
            if not finished(player, batch.previous, weapon or batch.weapon) then
                -- B42 multiplayer may deliver item/weapon synchronization after perform.
                batch.waitTicks = (batch.waitTicks or 0) + 1
                if batch.waitTicks > 300 then settle(player, batch, "Stopped") end
            elseif batch.index <= #batch.operations then
                batch.handles, batch.waitTicks, batch.issued = {}, 0, false
                local ok, err = pcall(A.advance, player, batch)
                if not ok then
                    print("[GMAW] action error: " .. tostring(err))
                    settle(player, batch, "Stopped")
                elseif not batch.issued then settle(player, batch, batch.error or "Stopped") end
            else
                local valid = weapon ~= nil
                for slot, fullType in pairs(batch.final) do
                    local part = weapon and weapon:getWeaponPart(slot)
                    if fullType == false then valid = valid and not part
                    else valid = valid and part and part:getFullType() == fullType end
                end
                settle(player, batch, valid and "Success" or "Stopped")
            end
        end
    end
end

function A.poll(player)
    local code = A.results[player]
    A.results[player] = nil
    return code
end

local function start(batch)
    A.results[batch.player] = nil
    A.active[batch.player] = batch
    -- First step is issued by the global tick, not by a window callback.
    return true
end

function A.begin(player, target, expected, choices, signature)
    if A.busy(player) or #ISTimedActionQueue.getTimedActionQueue(player).queue > 0 then return nil, "Busy" end
    local scan = S.scan(player)
    local source = scan.byID[target.item:getID()]
    if not source or source.key ~= target.key or not M.supported(source.item)
        or M.fingerprint(source.item) ~= expected then return nil, "Stale" end
    local weapon = source.item
    local catalog = M.candidates(weapon)
    local plan, reason = P.solve(catalog, M.installed(weapon), M.availability(catalog, scan), choices)
    if not plan then return nil, reason end
    if #plan == 0 or P.signature(plan) ~= signature then return nil, "Stale" end
    local requestedTools = {}
    for _, step in ipairs(plan) do
        if not collectTools(scan, requestedTools, step.slot) then return nil, "Tools" end
    end
    local order, why = B.preflight(player, weapon, catalog, plan, nil, hasEntries(requestedTools))
    if not order then return nil, why end
    for _, detached in ipairs(order.detached) do
        if not collectTools(scan, requestedTools, detached.slot) then return nil, "Tools" end
    end
    local batch = {player=player,weapon=weapon,weaponID=weapon:getID(),expected=expected,
        operations={},handles={},index=1,final={}}
    local seen = {}
    local function transfer(entry)
        local id = entry.item:getID()
        if not seen[id] and entry.item:getContainer() ~= player:getInventory() then
            batch.operations[#batch.operations+1] = {kind="transfer",id=id,key=entry.key}
        end
        seen[id] = true
    end
    transfer(source)
    for _, tool in pairs(requestedTools) do transfer(tool) end
    for _, step in ipairs(plan) do transfer(step.source) end
    for _, d in ipairs(order.detached) do
        batch.operations[#batch.operations+1] = {kind="detach",slot=d.slot,id=d.part:getID()}
    end
    for _, step in ipairs(plan) do
        batch.operations[#batch.operations+1] = {kind="install",slot=step.slot,id=step.source.item:getID(),
            fullType=step.fullType,generic=step.source.item:getFullType() ~= step.fullType}
        batch.final[step.slot] = step.fullType
    end
    for i = #order.detached, 1, -1 do
        local d = order.detached[i]
        if not d.replace then
            local generic = Universal.GetGenericItemTypeForOutcome(weapon, d.part)
            batch.operations[#batch.operations+1] = {kind="install",slot=d.slot,id=d.part:getID(),
                fullType=d.part:getFullType(),generic=generic ~= nil,refundType=generic}
            batch.final[d.slot] = d.part:getFullType()
        end
    end
    return start(batch)
end

function A.remove(player, target, expected, slot)
    if A.busy(player) or #ISTimedActionQueue.getTimedActionQueue(player).queue > 0 then return nil, "Busy" end
    local scan = S.scan(player)
    local source = scan.byID[target.item:getID()]
    if not source or source.key ~= target.key or not M.supported(source.item)
        or M.fingerprint(source.item) ~= expected then return nil, "Stale" end
    local weapon = source.item
    local order, reason = B.preflight(player, weapon, {}, {}, slot)
    if not order then return nil, reason end
    local requestedTools = {}
    for _, detached in ipairs(order.detached) do
        if not collectTools(scan, requestedTools, detached.slot) then return nil, "Tools" end
    end
    local batch = {player=player,weapon=weapon,weaponID=weapon:getID(),expected=expected,
        operations={},handles={},index=1,final={}}
    local seen = {}
    local function transfer(entry)
        local id = entry.item:getID()
        if not seen[id] and entry.item:getContainer() ~= player:getInventory() then
            batch.operations[#batch.operations+1] = {kind="transfer",id=id,key=entry.key}
        end
        seen[id] = true
    end
    transfer(source)
    for _, tool in pairs(requestedTools) do transfer(tool) end
    for _, d in ipairs(order.detached) do
        batch.operations[#batch.operations+1] = {kind="detach",slot=d.slot,id=d.part:getID()}
        batch.final[d.slot] = false
    end
    return start(batch)
end

-- Also observe cancellation during the short gap between native actions.
Events.OnKeyStartPressed.Add(function(key)
    if not getCore():isKey("CancelAction", key) and key ~= Keyboard.KEY_SPACE then return end
    local player = getSpecificPlayer(0)
    if player and A.active[player] then A.active[player].cancelled = true end
end)
Events.OnTick.Add(A.tick)
return A
