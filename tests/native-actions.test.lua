-- These constructors/complete functions are the installed vanilla + Gunworks Lua,
-- not replicas. Inventory/weapon Java objects are mocked, so this is not MP proof.
local gun=instanceItem("MarzGuns.M4A1")
local generic=instanceItem("MarzGuns.Picatinny_Rail")
local inv=inventory({generic})
function inv:contains(part) for _,p in ipairs(self.values) do if p==part then return true end end;return false end
function inv:containsID(id) for _,p in ipairs(self.values) do if p:getID()==id then return true end end;return false end
inv:AddItem(gun)
local player={getInventory=function() return inv end,isTimedActionInstant=function() return false end,setSecondaryHandItem=function() end}
gun.parts={}
function gun:getWeaponPart(slot) return self.parts[slot] end
function gun:attachWeaponPart(_,part) self.parts[part:getPartType()]=part end
function gun:detachWeaponPart(_,part) self.parts[part:getPartType()]=nil end
function gun:getAllWeaponParts() local out={};for _,p in pairs(self.parts) do out[#out+1]=p end;return javaList(out) end
local action=ISUpgradeWeapon:new(player,gun,generic,"MarzGuns.Picatinny_Rail_Up")
assert(action.maxTime==50 and action.outcomeFullType=="MarzGuns.Picatinny_Rail_Up")
assert(not gun.parts.RailUp and inv:contains(generic), "native construction does not assemble")
assert(action:isValid())
assert(action:complete())
assert(gun.parts.RailUp:getFullType()=="MarzGuns.Picatinny_Rail_Up" and not inv:contains(generic))
local remove=ISRemoveWeaponUpgrade:new(player,gun,"RailUp")
assert(remove.maxTime==50 and remove:isValid())
-- The universal refund uses AddItem(fullType); make only this mock match Java's overload.
local add=inv.AddItem
function inv:AddItem(part) if type(part)=="string" then part=instanceItem(part) end;return add(self,part) end
assert(remove:complete() and not gun.parts.RailUp)
local found=false
for _,p in ipairs(inv.values) do if p:getFullType()=="MarzGuns.Picatinny_Rail" then found=true end end
assert(found, "native removal returns the generic rail through Gunworks")
