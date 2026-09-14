-- Transport and replication are explicit test boundaries, not live sockets.
local A,M,S,P = require "GMAW/Actions",require "GMAW/Model",require "GMAW/Sources",require "GMAW/Planner"
local saved={supported=M.supported,candidates=M.candidates,scan=S.scan,client=isClient,server=isServer}
local gun,part=item("testGun",600),item("testPart",601,"Suppressor")
gun.parts={}
function gun:getWeaponPart(slot) return self.parts[slot] end
function gun:getAllWeaponParts() local out={};for _,p in pairs(self.parts) do out[#out+1]=p end;return javaList(out) end
function gun:attachWeaponPart(_, p) assert(isServer() and not isClient());self.parts[p:getPartType()]=p end
function gun:detachWeaponPart(_, p) assert(isServer() and not isClient());self.parts[p:getPartType()]=nil end
local inv=inventory({gun,part})
function inv:getItemById(id) for _,p in ipairs(self.values) do if p:getID()==id then return p end end end
gun.getContainer=function() return inv end;part.getContainer=gun.getContainer
local player={getInventory=function() return inv end,isDead=function() return false end,
    getPlayerNum=function() return 0 end,pressedCancelAction=function() return false end}
local target={item=gun,key="player"}
local source={item=part,key="player"}
local scan={byID={[600]=target,[601]=source},byType={testPart={source}},entries={target,source}}
local catalog={testPart={part=part,slot="Suppressor",consume="testPart",all={},any={}}}
M.supported=function() return true end;M.candidates=function() return catalog end;S.scan=function() return scan end
-- Avoid legacy GoM tool rules in this transport-only fixture.
local tools=M.toolGroups;M.toolGroups=function() return {} end
function isClient() return true end
function isServer() return false end
local pending
function sendClientCommand(who,module,command,args)
    assert(isClient() and who==player and module=="GMAW" and command=="apply")
    pending=args
end
local signature=P.signature(assert(P.solve(catalog,{},M.availability(catalog,scan),{"testPart"})))
assert(A.begin(player,target,"",{"testPart"},signature))
gmawTick()
local q=ISTimedActionQueue.getTimedActionQueue(player).queue
local action=table.remove(q,1)
assert(action and action.maxTime==50 and action:isValid())
assert(not gun.parts.Suppressor and inv:getItemById(601)==part and not pending)
action:perform()
assert(pending and not gun.parts.Suppressor and inv:getItemById(601)==part, "client does not attach or consume")
for i=1,3 do gmawTick() end
assert(A.busy(player) and #q==0, "wait for server state without duplicate action")
function isClient() return false end
function isServer() return true end
gmawServerCommand("GMAW","apply",player,pending)
assert(gun.parts.Suppressor==part and not inv:getItemById(601))
function isClient() return true end
function isServer() return false end
gmawTick()
assert(A.poll(player)=="Success" and not A.busy(player))
pending=nil
assert(A.remove(player,target,M.fingerprint(gun),"Suppressor"))
gmawTick();action=table.remove(q,1);assert(action and action:isValid());action:perform()
assert(pending and gun.parts.Suppressor==part, "client does not detach")
function isClient() return false end
function isServer() return true end
gmawServerCommand("GMAW","apply",player,pending)
function isClient() return true end
function isServer() return false end
gmawTick();assert(A.poll(player)=="Success" and inv:getItemById(601)==part)
M.supported,M.candidates,S.scan,M.toolGroups=saved.supported,saved.candidates,saved.scan,tools
isClient,isServer=saved.client,saved.server
