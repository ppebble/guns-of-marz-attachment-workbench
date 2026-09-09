for _, name in ipairs({"ISUI/ISInventoryPaneContextMenu","ISUI/ISInventoryPage","TimedActions/ISQueueActionsAction",
    "TimedActions/ISInventoryTransferUtil","WeaponSystems/Hooks/WeaponUpgradeHooks","MarzWeapons/ISUI/RequiredToolVisualEquipt"}) do modules[name]={} end
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
    return {player=player,kind="transfer",item=item,source=source,dest=dest}
end}
ISInventoryPaneContextMenu={transferIfNeeded=function() end,equipWeapon=function() end}
function ISInventoryPaneContextMenu.onRemoveUpgradeWeapon(weapon,part,player)
    ISTimedActionQueue.add({player=player,kind="detach",weapon=weapon,part=part})
end
function ISInventoryPaneContextMenu.onUpgradeWeapon(weapon,part,player)
    ISTimedActionQueue.add({player=player,kind="install",weapon=weapon,part=part})
end
ISUpgradeWeapon={new=function(_,player,weapon,part,outcome)
    return {player=player,kind="install",weapon=weapon,part=part,outcome=outcome}
end}
MarzGuns_AttachAndDetach={getPrimaryTool=function() return nil end}
local R=require "WeaponSystems/Utils/RequiredAttachment"
R.IsRemovalBlocked=function() return false end; R.IsInstallationBlocked=function() return false end
local E=require "WeaponSystems/Utils/UpgradeExclusives"
E.IsBlockedByExclusive=function() return false end
local U=require "WeaponSystems/Utils/UniversalAttachment"
U.CanInstallOutcome=function() return true end
