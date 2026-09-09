for _, name in ipairs({"ISUI/ISInventoryPaneContextMenu","ISUI/ISInventoryPage","TimedActions/ISQueueActionsAction",
    "TimedActions/ISInventoryTransferUtil","WeaponSystems/Hooks/WeaponUpgradeHooks","MarzWeapons/ISUI/RequiredToolVisualEquipt"}) do modules[name]={} end
local Base = {}
function Base:derive() local t = {}; setmetatable(t, {__index=self}); return t end
function Base.new(_, _, player) return setmetatable({character=player}, {__index=Base}) end
function Base:stop() end
function Base:perform() end
function Base:getJobDelta() return 1 end
modules["TimedActions/ISBaseTimedAction"] = Base
ISBaseTimedAction = Base
local queues = {}
ISTimedActionQueue = {}
function ISTimedActionQueue.getTimedActionQueue(player)
    queues[player]=queues[player] or {queue={}}; return queues[player]
end
function ISTimedActionQueue.hasAction(action)
    for _,q in pairs(queues) do for _,a in ipairs(q.queue) do if a==action then return true end end end
    return false
end
function ISTimedActionQueue.add(action)
    local q=ISTimedActionQueue.getTimedActionQueue(action.player)
    table.insert(q.queue,action); return q,action
end
function ISTimedActionQueue.queueActions(player,callback,batch)
    return ISTimedActionQueue.add({player=player,kind="dispatch",callback=callback,batch=batch})
end
ISInventoryTransferUtil={newInventoryTransferAction=function(player,item,source,dest)
    return {player=player,kind="transfer",item=item,source=source,dest=dest,perform=function() end}
end}
ISInventoryPaneContextMenu={transferIfNeeded=function() end,equipWeapon=function() end}
function ISInventoryPaneContextMenu.onRemoveUpgradeWeapon(weapon,part,player)
    ISTimedActionQueue.add({player=player,kind="detach",weapon=weapon,part=part,perform=function() end})
end
function ISInventoryPaneContextMenu.onUpgradeWeapon(weapon,part,player)
    ISTimedActionQueue.add({player=player,kind="install",weapon=weapon,part=part,perform=function() end})
end
ISUpgradeWeapon={new=function(_,player,weapon,part,outcome)
    return {player=player,kind="install",weapon=weapon,part=part,outcome=outcome,perform=function() end}
end}
ISRemoveWeaponUpgrade={complete=function() end}
MarzGuns_AttachAndDetach={getPrimaryTool=function() return nil end}
local R=require "WeaponSystems/Utils/RequiredAttachment"
R.IsRemovalBlocked=function() return false end; R.IsInstallationBlocked=function() return false end
local E=require "WeaponSystems/Utils/UpgradeExclusives"
E.IsBlockedByExclusive=function() return false end
local U=require "WeaponSystems/Utils/UniversalAttachment"
U.CanInstallOutcome=function() return true end
