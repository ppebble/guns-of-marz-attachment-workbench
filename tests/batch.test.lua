local B = require "GMAW/Batch"
local R = require "WeaponSystems/Utils/RequiredAttachment"
local old, new, rail = item("old", 1, "Scope"), item("new", 2, "Scope"), item("rail", 3, "RailUp")
local w = {parts={Scope=old}}
function w:getAllWeaponParts() local list={}; for _,p in pairs(self.parts) do list[#list+1]=p end; return javaList(list) end
local player = {}
local plan = {{fullType="new",slot="Scope",old=old,source={item=new}}}
local order=assert(B.preflight(player,w,{},plan))
assert(order.detached[1].part==old and w.parts.Scope==old, "preflight never mutates")
new.canAttach=function() return false end
assert(not B.preflight(player,w,{},plan)); new.canAttach=function() return true end
old.canDetach=function() return false end
assert(not B.preflight(player,w,{},plan)); old.canDetach=function() return true end
R.AnyDependencies.old={rail=true,rail2=true}
local rail2=item("rail2",4,"RailUp"); w.parts={RailUp=rail,Scope=old}
order=assert(B.preflight(player,w,{},{{fullType="rail2",slot="RailUp",old=rail,source={item=rail2}}}))
assert(order.detached[1].part==old and order.detached[2].part==rail)
assert(not B.commit and not B.publish, "instant mutation API removed")
