local M,T,V = require "GMAW/Model",require "GMAW/Attachments",require "GMAW/Presentation"
local Authority = require "GMAW/Authority"
local gun=instanceItem("MarzGuns.M4A1")
assert(M.supported(gun))
local cat=M.candidates(gun)
local simple="SimpleSuppressors.Suppressor_556"
assert(cat[simple] and cat[simple].slot == "Suppressor")
assert(cat[simple].excludes[simple], "actual Simple Suppressors bridge registers self-exclusion")
assert(not cat["SimpleSuppressors.Suppressor_9mm"], "wrong calibers hidden despite broad MountOn")
assert(M.candidates(instanceItem("MarzGuns.M1911"))["SimpleSuppressors.Suppressor_45ACP"], "GoM .45 item key is registered")
assert(M.candidates(instanceItem("MarzGuns.M14"))["SimpleSuppressors.Suppressor_308"], "GoM .308 item key is registered")
for _, id in ipairs({"Silencer","MetalPipeSilencer","TorchSilencer","WaterBottleSilencer","PotatoSilencer"}) do
    assert(cat["Base."..id], "ISIL GoM runtime MountOn integration: "..id)
end
local shotgun=M.candidates(instanceItem("MarzGuns.MOSSBERG_590"))
assert(shotgun["Base.Silencer"] and shotgun["Base.MetalPipeSilencer"])
assert(not shotgun["Base.PotatoSilencer"] and not shotgun["Base.TorchSilencer"])
assert(shotgun["SimpleSuppressors.Suppressor_12Gauge"])
assert(not M.candidates(instanceItem("MarzGuns.MP5SD"))[simple], "integral suppressor excluded")
SandboxVars.SimpleSuppressors.Enable556Suppressors=false
assert(not M.candidates(gun)[simple], "sandbox caliber restriction stays authoritative")
SandboxVars.SimpleSuppressors.Enable556Suppressors=nil
local foreign=instanceItem(simple); foreign.class="HandWeapon"; foreign.isRanged=function() return true end
assert(not M.supported(foreign), "part-only allowance does not admit addon firearms")
for _, owner in ipairs({"SimpleSuppressors","ImprovisedSilencers"}) do
    attachmentActive[owner]=nil; M.cache=nil
    for _, part in pairs(M.catalog()) do assert(part:getModID() ~= owner) end
    attachmentActive[owner]=true
end
M.cache=nil
cat=M.candidates(gun)
local inv=inventory({gun})
function inv:getItemById(id) for _, p in ipairs(self.values) do if p:getID()==id then return p end end end
function inv:contains(p) return self:getItemById(p:getID()) ~= nil end
function inv:containsID(id) return self:getItemById(id) ~= nil end
local player={hasScrewdriver=false,getInventory=function() return inv end,isTimedActionInstant=function() return false end,
    getPrimaryHandItem=function() return nil end,getSecondaryHandItem=function() return nil end,
    setSecondaryHandItem=function() end,getOnlineID=function() return 1 end}
function inv:getFirstTypeRecurse() return player.hasScrewdriver and {} or nil end
function gun:getContainer() return inv end
function gun:getModData() self.md=self.md or {};return self.md end
function gun:getSoundRadius() return 1 end
function gun:getSoundVolume() return 1 end
function gun:getSwingSound() return "test" end
function getOnlinePlayers() return javaList({}) end
local callbacks=0
-- Observe actual upstream completion hook dispatch; engine sound/condition math
-- and rendered effects are not simulated or claimed as verified here.
ISILSilencerStats.apply=function() callbacks=callbacks+1 end
ISILSilencerDurability.initialize=function() callbacks=callbacks+1 end
local part=instanceItem(simple)
assert(#M.toolGroups("Suppressor",part)==0)
assert(#M.toolGroups("Suppressor",part,true)==1)
local potato=instanceItem("Base.PotatoSilencer")
assert(#M.toolGroups("Canon",potato)==0)
assert(M.toolGroups("Canon",instanceItem("Base.Silencer"))[1][1]==ItemTag.SCREWDRIVER)
inv:AddItem(part)
local available={[simple]={{item=part,key="player"}}}
local view=V.build(cat,{},available,{},player,gun,{byType={}})
assert(view.bySlot.Suppressor, "localized slot appears in workbench view model")
local found=false
for _, option in ipairs(view.bySlot.Suppressor.options) do
    if option.fullType==simple then assert(not option.dim);found=true end
end
assert(found, "owned compatible suppressor selectable without wrench or screwdriver")
local checkedRail = false
for fullType, candidate in pairs(cat) do
    if candidate.slot == "RailUp" then
        local rail = instanceItem(fullType)
        assert(require("GMAW/Planner").solve(cat, {Suppressor=part},
            {[fullType]={{item=rail,key="player"}}}, {fullType}),
            "preinstalled Simple Suppressors must not block unrelated rail")
        checkedRail = true
        break
    end
end
assert(checkedRail, "fixture includes unrelated rail")
-- SP uses the upstream timed action, including its duration and completion.
local action=T.action(player,gun,part,false)
assert(action.maxTime==50 and action:isValid() and action:complete())
assert(gun.parts.Suppressor==part and not inv:contains(part))
assert(not T.action(player,gun,part,true):isValid(), "removal requires upstream screwdriver")
player.hasScrewdriver=true
assert(T.action(player,gun,part,true):isValid())
assert(T.action(player,gun,part,true):complete() and inv:contains(part))
-- MP authority must use upstream hooks, reject forged swaps, and not consume twice.
function isServer() return true end
local ok,_,direction=Authority.apply(player,{kind="install",weaponID=gun:getID(),partID=part:getID(),slot="Suppressor",fullType=simple})
assert(ok and direction=="native" and gun.parts.Suppressor==part)
assert(not Authority.apply(player,{kind="install",weaponID=gun:getID(),partID=part:getID(),slot="Suppressor",fullType=simple}))
assert(Authority.apply(player,{kind="detach",weaponID=gun:getID(),partID=part:getID(),slot="Suppressor"}))
inv:AddItem(potato)
player.hasScrewdriver=false
ok,_,direction=Authority.apply(player,{kind="install",weaponID=gun:getID(),partID=potato:getID(),slot="Canon",fullType=potato:getFullType()})
assert(ok and direction=="native" and gun.parts.Canon==potato and callbacks==2)
assert(Authority.apply(player,{kind="detach",weaponID=gun:getID(),partID=potato:getID(),slot="Canon"}))
assert(callbacks==3 and inv:contains(potato), "ISIL remove restores through upstream completion")
SandboxVars.SimpleSuppressors.Enable556Suppressors=false
assert(not Authority.apply(player,{kind="install",weaponID=gun:getID(),partID=part:getID(),slot="Suppressor",fullType=simple}))
SandboxVars.SimpleSuppressors.Enable556Suppressors=nil
assert(not Authority.apply(player,{kind="install",weaponID=gun:getID(),partID=part:getID(),slot="Canon",fullType=simple}))
assert(not Authority.apply(player,{kind="install",weaponID=gun:getID(),partID=part:getID(),slot="Suppressor",fullType=simple,generic=true}))
assert(inv:contains(part) and not gun.parts.Suppressor)
local removed, added = 0, 0
function sendRemoveItemFromContainer(_, changed) assert(changed==part); removed=removed+1 end
function sendAddItemToContainer(_, changed) assert(changed==part); added=added+1 end
gmawServerCommand("GMAW", "apply", player, {kind="install",weaponID=gun:getID(),partID=part:getID(),slot="Suppressor",fullType=simple})
assert(removed==1 and added==0 and gun.parts.Suppressor==part, "no duplicate server inventory notification")
player.hasScrewdriver=true
gmawServerCommand("GMAW", "apply", player, {kind="detach",weaponID=gun:getID(),partID=part:getID(),slot="Suppressor"})
assert(removed==1 and added==1 and inv:contains(part) and not gun.parts.Suppressor)
