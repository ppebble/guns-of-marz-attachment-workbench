-- Real installed vanilla/Gunworks/GoM completion chain, mocked Java inventory and transport.
local Authority = require "GMAW/Authority"
function getActivatedMods() return {contains=function(_,id) return id==installedModID end} end
local Stats = require "WeaponSystems/Utils/StatsFactory"
local Underbarrel = require "WeaponSystems/Utils/Underbarrel"
local stats, cleanup, added, removed = 0, 0, 0, 0
Stats.ReapplyAllModifiers = function() stats=stats+1 end
Underbarrel.HandleAttachmentRemoval = function() cleanup=cleanup+1 end
function sendRemoveItemFromContainer() removed=removed+1 end
function sendAddItemToContainer() added=added+1 end
local gun = instanceItem("MarzGuns.M4A1")
local rail = instanceItem("MarzGuns.Picatinny_Rail")
local inv = inventory({gun, rail})
function inv:getItemById(id) for _,p in ipairs(self.values) do if p:getID()==id then return p end end end
function inv:contains(p) return self:getItemById(p:getID())==p end
function inv:containsID(id) return self:getItemById(id)~=nil end
local add=inv.AddItem
function inv:AddItem(p) return add(self,type(p)=="string" and instanceItem(p) or p) end
gun.parts={}
function gun:getWeaponPart(slot) return self.parts[slot] end
function gun:attachWeaponPart(_,p) self.parts[p:getPartType()]=p end
function gun:detachWeaponPart(_,p) self.parts[p:getPartType()]=nil end
function gun:getAllWeaponParts() local out={};for _,p in pairs(self.parts) do out[#out+1]=p end;return javaList(out) end
local player={getInventory=function() return inv end,isTimedActionInstant=function() return false end,setSecondaryHandItem=function() end}
local request={kind="install",weaponID=gun:getID(),partID=rail:getID(),slot="RailUp",fullType="MarzGuns.Picatinny_Rail_Up",generic=true}
local ok,_,direction=Authority.apply(player,request)
assert(ok and direction=="native" and gun.parts.RailUp and not inv:contains(rail))
assert(stats==1 and removed==1)
ok=Authority.apply(player,{kind="detach",weaponID=gun:getID(),partID=gun.parts.RailUp:getID(),slot="RailUp"})
assert(ok and not gun.parts.RailUp and stats==2 and cleanup==1 and added==1)
local refund=inv.values[#inv.values]
assert(refund:getFullType()=="MarzGuns.Picatinny_Rail", "MP authority uses upstream generic refund")
local wrong=instanceItem("MarzGuns.M4A1");inv:AddItem(wrong)
request.partID=wrong:getID()
assert(not Authority.apply(player,request) and inv:contains(wrong) and not gun.parts.RailUp, "arbitrary items cannot fund outcomes")
request.partID=refund:getID();request.slot="Scope"
assert(not Authority.apply(player,request) and inv:contains(refund), "declared slot must match outcome")
request.slot="RailUp"
assert(Authority.apply(player,request))
Underbarrel.IsWeaponInUnderbarrelMode=function() return true end
assert(not Authority.apply(player,{kind="detach",weaponID=gun:getID(),slot="RailUp"}), "native underbarrel-mode removal guard remains active")
assert(gun.parts.RailUp and added==1)
