local M, T = require "GMAW/Model", require "GMAW/Attachments"
local Authority = require "GMAW/Authority"
local savedMods,savedManager,savedItem,savedType,savedCache = getActivatedMods,getScriptManager,instanceItem,ItemType,M.cache
local active = {GunsOfMarz=true,GaelGunStore_B42=true}
function getActivatedMods() return {contains=function(_,id) return active[id] == true end} end
ItemType={WEAPON_PART="weaponpart"}
local function firearm(owner,id,fullType)
    local v=item(fullType,id);v.class="HandWeapon"
    function v:getModID() return owner end
    function v:isRanged() return true end
    function v:getWeaponPart() return nil end
    function v:getAllWeaponParts() return javaList({}) end
    return v
end
local gom=firearm("GunsOfMarz",501,"MarzGuns.M4A1")
local gael=firearm("GaelGunStore_B42",502,"Base.M4")
local emre=firearm("EmreFirearmsPack_B42",505,"ENF2.AR15")
local emptyEmre=firearm("EmreFirearmsPack_B42",506,"EFS.Unmapped")
local emptyGoM=firearm("GunsOfMarz",507,"MarzGuns.Unmapped")
local emptyVanilla=firearm("pz-vanilla",508,"Base.Unmapped")
local function scope(owner,id,fullType)
    local v=item(fullType,id,"Scope")
    function v:getModID() return owner end
    function v:getMountOn() return javaList({"Base.M4","MarzGuns.M4A1","ENF2.AR15"}) end
    return v
end
local gs,as=scope("GunsOfMarz",503,"MarzGuns.Scope"),scope("GaelGunStore_B42",504,"Base.Accupoint")
local parts={[gs:getFullType()]=gs,[as:getFullType()]=as}
function instanceItem(id) return parts[id] end
local scripts={}
for id,part in pairs(parts) do
    local key,value=id,part
    scripts[#scripts+1]={getModID=function() return value:getModID() end,getFullName=function() return key end,
        getObsolete=function() return false end,isItemType=function() return true end}
end
function getScriptManager() return {getAllItems=function() return javaList(scripts) end} end
local oldDependencies=modules["GGS_AttachmentDependencies"]
modules["GGS_AttachmentDependencies"]={isSlotUnlocked=function() return true end,isSlotDependent=function() return false end,getProviderUnlocks=function() return {} end}
M.cache=nil
assert(M.supported(gom) and M.supported(gael),"both provider weapons visible")
assert(M.candidates(gom)[gs:getFullType()] and not M.candidates(gom)[as:getFullType()],"GoM catalog rejects Gael scope despite forged MountOn")
assert(M.candidates(gael)[as:getFullType()] and not M.candidates(gael)[gs:getFullType()],"Gael catalog rejects GoM scope despite forged MountOn")
assert(not T.compatible(gs,gael) and not T.compatible(as,gom),"cross-provider compatibility rejected both directions")
local inv=inventory({gom,gael,gs,as})
function inv:getItemById(id) for _,v in ipairs(self.values) do if v:getID()==id then return v end end end
local player={getInventory=function() return inv end}
local ok,reason=Authority.apply(player,{kind="install",weaponID=501,partID=503,slot="Scope",fullType=gs:getFullType()})
assert(not ok and reason=="NativeConflict","coactive upstream global action replacement blocks GoM safely")
ok,reason=Authority.apply(player,{kind="install",weaponID=502,partID=503,slot="Scope",fullType=gs:getFullType()})
assert(not ok and reason=="Part","coactive server rejects cross-provider install")
active={GunsOfMarz=true};M.cache=nil
assert(M.supported(gom) and not M.supported(gael) and M.actionSafe(gom),"GoM-only remains usable")
active={GaelGunStore_B42=true};M.cache=nil
assert(M.supported(gael) and not M.supported(gom),"Gael-only ownership")
active={};M.cache=nil
assert(not M.enabled() and not M.supported(gom) and not M.supported(gael),"neither-provider ownership")
-- Exercise the registered context-menu callback, not a replica of its gate.
local savedInstanceof=instanceof
function instanceof(value,class)
    if class=="InventoryItem" then return value and value.getFullType~=nil end
    return savedInstanceof(value,class)
end
local function menu(items)
    local context={options={}}
    function context:addOption(label,player,callback,weapon)
        self.options[#self.options+1]={label=label,player=player,callback=callback,weapon=weapon}
    end
    gmawInventoryMenu(0,context,items)
    return context.options
end
assert(#menu({gom})==0,"no-provider context is absent")
active={GunsOfMarz=true};M.cache=nil
local options=menu({{items={gom}},emptyGoM})
assert(#options==1 and options[1].weapon==gom and options[1].callback==require("GMAW/Window").open,
    "grouped GoM selection opens common UI exactly once")
assert(#menu({emptyGoM,emptyVanilla,emre})==0,"empty GoM/vanilla and unbridged Emre have no useless menu")
active={GaelGunStore_B42=true};M.cache=nil
options=menu({gael})
assert(#options==1 and options[1].weapon==gael,"Gael-only direct inventory selection opens UI")
gs.class="WeaponPart"
assert(#menu({gs})==0,"attachment item is not a weapon context target")
active={GunsOfMarz=true,EmreFirearmsPack_B42=true,EmreFPGoMCompat=true};M.cache=nil
options=menu({emre})
assert(#options==1 and options[1].weapon==emre,"mapped Emre native GoM bridge opens shared UI")
assert(#menu({emptyEmre})==0,"unmapped Emre menu hidden")
active={GunsOfMarz=true,EmreFirearmsPack_B42=true};M.cache=nil
assert(#menu({emre})==0,"missing Emre bridge hides menu")
active={MarzGuns=true,EmreFirearmsPack_B42=true,EmreFPGoMCompat=true};M.cache=nil
assert(#menu({emre})==0,"legacy GoM cannot activate current Emre bridge")
local A=require "GMAW/Adapters"
local bridge=firearm("FutureGaelWeaponBridge",509,"Base.M4")
active={GaelGunStore_B42=true,FutureGaelWeaponBridge=true};M.cache=nil
assert(not M.supported(bridge) and not T.compatible(as,bridge),"unknown owner never inherits Gael from its Base fullType")
A.registerWeapon("test-gael-system-bridge",{owner="FutureGaelWeaponBridge",
    requires={"FutureGaelWeaponBridge","GaelGunStore_B42"},attachmentSystem="gael",
    mountOwners={GaelGunStore_B42=true}})
assert(M.supported(bridge) and M.providerFor(bridge).attachmentSystem=="gael",
    "explicit bridge selects attachment system independently of original weapon owner")
assert(T.compatible(as,bridge) and T.canAttach(as,{},bridge) and not T.compatible(gs,bridge),
    "explicit Gael bridge uses Gael callbacks and preserves part isolation")
assert(#menu({bridge})==1,"explicit registered Gael bridge uses common opening gate")
instanceof=savedInstanceof
modules["GGS_AttachmentDependencies"]=oldDependencies
getActivatedMods,getScriptManager,instanceItem,ItemType,M.cache=savedMods,savedManager,savedItem,savedType,savedCache
