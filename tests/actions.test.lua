local A,M,S,P=require "GMAW/Actions",require "GMAW/Model",require "GMAW/Sources",require "GMAW/Planner"
local saved={supported=M.supported,candidates=M.candidates,scan=S.scan}
local inv=inventory({})
function inv:getFirstTagEvalRecurse(tag, predicate)
    for _, p in ipairs(self.values) do
        if p.hasTag and p:hasTag(tag) and predicate(p) then return p end
    end
end
function inv:containsID(id) return self:getItemById(id)~=nil end
function inv:getItemById(id) for _,p in ipairs(self.values) do if p:getID()==id then return p end end end
local player={getInventory=function() return inv end,getPlayerNum=function() return 0 end,isDead=function() return false end,pressedCancelAction=function() return false end}
local gun=item("gun",90);gun.parts={}
function gun:getAllWeaponParts() local t={};for _,p in pairs(self.parts) do t[#t+1]=p end;return javaList(t) end
function gun:getWeaponPart(slot) return self.parts[slot] end
ItemTag={SCREWDRIVER="screwdriver",WRENCH="wrench",PIPE_WRENCH="pipe_wrench"}
local rail=item("generic",1,"RailUp");local scope=item("scope",2,"Scope")
local screwdriver=item("screwdriver",4,"Tool"); screwdriver.hasTag=function(_, tag) return tag==ItemTag.SCREWDRIVER end
local crate=inventory({gun,rail,scope,screwdriver})
for _,p in ipairs(crate.values) do p.container=crate; p.getContainer=function(self) return self.container end end
local catalog={up={slot="RailUp",part=item("up",3,"RailUp"),consume="generic",all={},any={}},
    scope={slot="Scope",part=scope,consume="scope",all={},any={up=true}}}
local target={item=gun,key="crate"}
function S.scan()
    local scan={entries={},byID={},byType={}}
    for _,p in ipairs({gun,rail,scope,screwdriver}) do
        local e={item=p,key=p.container==inv and "player" or "crate"}
        scan.entries[#scan.entries+1]=e
        scan.byID[p:getID()]=e
        scan.byType[p:getFullType()]={e}
    end
    return scan
end
M.supported=function() return true end;M.candidates=function() return catalog end
function instanceItem(ft) return item(ft,3,"RailUp") end
local signature=P.signature(assert(P.solve(catalog,{},M.availability(catalog,S.scan()),{"scope"})))
assert(not A.begin(player,target,"stale",{"scope"},signature))
assert(A.begin(player,target,"",{"scope"},signature))
assert(#inv.values==0 and not gun.parts.Scope, "enqueue does not transfer or attach")
assert(A.busy(player) and not A.begin(player,target,"",{"scope"},signature))
local executed={}
local q=ISTimedActionQueue.getTimedActionQueue(player).queue
local function runOne()
    gmawTick() -- no window exists or updates
    local action=q[1]
    if not action then return end
    if action.kind=="transfer" then
        executed[#executed+1]="transfer"
        action.source:Remove(action.item);inv:AddItem(action.item);action.item.container=inv
    elseif action.kind=="detach" then
        executed[#executed+1]="detach:"..action.part:getFullType()
        gun.parts[action.part:getPartType()]=nil
        inv:AddItem(action.part);action.part.container=inv
    else
        executed[#executed+1]=action.outcome or action.part:getFullType()
        assert(inv:containsID(90), "weapon transferred before assembly")
        inv:Remove(action.part)
        local p=action.outcome and item(action.outcome,30,"RailUp") or action.part
        gun.parts[p:getPartType()]=p
    end
    table.remove(q,1)
    action:perform()
end
for i=1,10 do runOne() end
assert(table.concat(executed,",")=="transfer,transfer,transfer,transfer,up,scope",
    "weapon, nearby tool, parts, then dependency-first native actions")
assert(A.poll(player)=="Success" and not A.busy(player))
-- Removal cascades through railing registration, children before parent, no reinstall.
local railing=require "WeaponSystems/Utils/Railing"
railing.AcceptedAccessories.up={"scope"}
local localTarget={item=gun,key="player"}
assert(A.remove(player,localTarget,M.fingerprint(gun),"RailUp"))
executed={}
for i=1,5 do runOne() end
assert(table.concat(executed,",")=="detach:scope,detach:up")
assert(A.poll(player)=="Success" and not gun.parts.Scope and not gun.parts.RailUp)
railing.AcceptedAccessories.up=nil
-- Cancellation after a native transfer preserves that transfer; no rollback/magic inventory edits.
gun.parts={}; inv.values={};crate.values={gun,rail,scope,screwdriver}
for _,p in ipairs(crate.values) do p.container=crate end
assert(A.begin(player,target,"",{"scope"},signature))
gmawTick()
local transfer=q[1]; transfer.source:Remove(transfer.item);inv:AddItem(transfer.item);transfer.item.container=inv
transfer:stop(); while #q>0 do table.remove(q) end
gmawTick()
assert(A.poll(player)=="Stopped" and inv:containsID(90) and not gun.parts.Scope)
-- A completed motion is not success until authoritative item changes are visible.
gun.parts={};inv.values={gun,rail,scope,screwdriver}
for _,p in ipairs(inv.values) do p.container=inv end
signature=P.signature(assert(P.solve(catalog,{},M.availability(catalog,S.scan()),{"scope"})))
assert(A.begin(player,{item=gun,key="player"},"",{"scope"},signature))
gmawTick()
local delayed=table.remove(q,1)
delayed:perform()
for i=1,3 do gmawTick() end
assert(A.busy(player) and #q==0 and A.poll(player)==nil, "wait for replicated result, not another motion")
inv:Remove(rail);gun.parts.RailUp=item("up",31,"RailUp")
gmawTick();assert(#q==1 and q[1].part==scope, "resume only after parent exists")
q[1]:stop();while #q>0 do table.remove(q) end
gmawTick();assert(A.poll(player)=="Stopped")
for i=1,5 do gmawTick() end
assert(#q==0 and not gun.parts.Scope, "explicit stop never resumes")
-- A completed action that never mutates fails instead of falsely reporting success.
gun.parts={};inv.values={gun,rail,scope,screwdriver}
assert(A.begin(player,{item=gun,key="player"},"",{"scope"},signature))
gmawTick();local failed=table.remove(q,1);failed:perform()
for i=1,301 do gmawTick() end
assert(A.poll(player)=="Stopped" and #q==0 and not gun.parts.Scope)
M.supported,M.candidates,S.scan=saved.supported,saved.candidates,saved.scan
