local M = require "GMAW/Model"
local T = require "GMAW/Attachments"
local Authority = require "GMAW/Authority"
local records = gaelRecords or {
    ["Base.M4"]={fullType="Base.M4",type="base:weapon",mounts={}},
    ["Base.Accupoint"]={fullType="Base.Accupoint",type="base:weaponpart",slot="Scope",mounts={"Base.M4"}},
    ["Base.M203_GL"]={fullType="Base.M203_GL",type="base:weaponpart",slot="Stool",mounts={"Base.M4"}},
}
local serial, scripts = 1000, {}
function instanceItem(fullType)
    local r = assert(records[fullType], fullType)
    serial = serial + 1
    local value = item(fullType, serial, r.slot)
    value.class = r.type == "base:weaponpart" and "WeaponPart" or "HandWeapon"
    value.parts, value.data = {}, {grenadeRounds=1}
    function value:getModID() return "GaelGunStore_B42" end
    function value:getName() return fullType end
    function value:isRanged() return true end
    function value:getMountOn() return javaList(r.mounts or {}) end
    function value:getWeaponPart(slot) return self.parts[slot] end
    function value:getAllWeaponParts() local out={};for _,p in pairs(self.parts) do out[#out+1]=p end;return javaList(out) end
    function value:attachWeaponPart(_,part) self.parts[part:getPartType()] = part end
    function value:detachWeaponPart(_,part) self.parts[part:getPartType()] = nil end
    function value:getModData() return self.data end
    function value:canAttach(player) return player.hasScrewdriver end
    function value:canDetach(player) return player.hasScrewdriver end
    return value
end
for fullType, r in pairs(records) do
    local id, record = fullType, r
    scripts[#scripts+1] = {
        getModID=function() return "GaelGunStore_B42" end,
        getFullName=function() return id end,
        getObsolete=function() return false end,
        isItemType=function(_,kind) return kind == ItemType.WEAPON_PART and record.type == "base:weaponpart" end,
    }
end
function getScriptManager() return {getAllItems=function() return javaList(scripts) end} end
local weapon, scope, grenade = instanceItem("Base.M4"), instanceItem("Base.Accupoint"), instanceItem("Base.M203_GL")
local inv = inventory({weapon,scope,grenade})
local carriedTool = testTool(ItemTag.SCREWDRIVER)
inv:AddItem(carriedTool)
function inv:getItemById(id) for _,p in ipairs(self.values) do if p:getID()==id then return p end end end
function inv:contains(part) for _,p in ipairs(self.values) do if p==part then return true end end;return false end
local player = {hasScrewdriver=true,getInventory=function() return inv end,isTimedActionInstant=function() return false end,
    setSecondaryHandItem=function() end}
M.cache=nil
assert(M.enabled() and M.supported(weapon), "Gael alone opens common workbench")
local candidates = M.candidates(weapon)
assert(candidates[scope:getFullType()], "Gael native scope visible")
do
    local beam=item("Base.ANPEQ_10_BEAM",29999,"Hide_Beam")
    function beam:getModID() return "GaelGunStore_B42" end
    function beam:getMountOn() return javaList({weapon:getFullType()}) end
    function beam:canAttach() return true end
    function beam:canDetach() return true end
    local original=M.cache
    M.cache={[beam:getFullType()]=beam,[scope:getFullType()]=scope}
    assert(not M.candidates(weapon)[beam:getFullType()],"native visual beam excluded from candidates")
    assert(not M.isCandidate(weapon,beam:getFullType()),"beam rejected by single-part admission")
    assert(not T.canPlanAttach(beam,player,weapon),"beam cannot enter preview plan")
    inv:AddItem(beam)
    assert(not Authority.apply(player,{kind="install",weaponID=weapon:getID(),partID=beam:getID(),slot="Hide_Beam",fullType=beam:getFullType()}),"forged beam install denied")
    weapon.parts.Hide_Beam=beam
    local beamView=require("GMAW/Presentation").build(M.candidates(weapon),M.installed(weapon),{},{},player,weapon)
    assert(not beamView.bySlot.Hide_Beam,"already active native beam is hidden from slot UI")
    assert(not Authority.apply(player,{kind="detach",weaponID=weapon:getID(),partID=beam:getID(),slot="Hide_Beam"}),"forged beam removal denied")
    assert(weapon.parts.Hide_Beam==beam,"native effect remains untouched")
    weapon.parts.Hide_Beam=nil;inv:Remove(beam);M.cache=original
    for fullType,r in pairs(records) do
        if r.slot=="Hide_Beam" or r.slot=="Clip" or r.slot=="AMMO" or r.slot=="Stool"
            or fullType=="Base.bipod_harris_open" or fullType=="Base.bipod_old_open"
            or fullType=="Base.bipod_simple_open" or fullType=="Base.scrap_bipod_open" then
            assert(not M.catalog()[fullType],"installed effect absent from catalog: "..fullType)
        elseif r.type=="base:weaponpart" then
            assert(M.catalog()[fullType],"real accessory preserved: "..fullType)
        end
    end
end
do
    -- Count bridge calls, rather than wall time, to catch the quadratic catalog
    -- scan reliably in both the Kahlua harness and the real installed fixtures.
    local original, reads, count = M.cache, 0, 80
    local synthetic = {}
    for i=1,count do
        local part=item("Base.PerformanceScope"..i,20000+i,"Scope")
        function part:getModID() return "GaelGunStore_B42" end
        function part:getMountOn() reads=reads+1;return javaList({weapon:getFullType()}) end
        synthetic[part:getFullType()]=part
    end
    M.cache=synthetic
    local rebuilt=M.candidates(weapon)
    assert(#M.keys(rebuilt)==count,"performance fixture retains all eligible parts")
    assert(reads<=count*3,"Gael metadata must scan catalog linearly, MountOn reads="..reads)
    reads=0
    assert(M.isCandidate(weapon,"Base.PerformanceScope1"),"single-part membership preserves admission")
    assert(reads==1,"single-part membership never builds the catalog metadata graph")
    assert(not M.isCandidate(weapon,"Base.MissingPart"),"unknown candidate fails closed")

    local api=require "GGS_AttachmentDependencies"
    local originalDependent,originalUnlocks=api.isSlotDependent,api.getProviderUnlocks
    local parent=synthetic["Base.PerformanceScope2"]
    function parent:getPartType() return "Mount" end
    api.isSlotDependent=function(_,slot) return slot=="Scope" end
    api.getProviderUnlocks=function(fullType)
        return fullType==parent:getFullType() and {"Scope"} or {}
    end
    rebuilt=M.candidates(weapon)
    assert(rebuilt["Base.PerformanceScope1"].any[parent:getFullType()],"dependency graph rebuilt from current native data")
    api.isSlotDependent=function() return false end
    rebuilt=M.candidates(weapon)
    assert(#M.keys(rebuilt["Base.PerformanceScope1"].any)==0,"dependency updates are not hidden by persistent cache")
    local sideScope=synthetic["Base.PerformanceScope3"]
    function sideScope:getPartType() return "L_Scope" end
    rebuilt=M.candidates(weapon)
    assert(rebuilt[sideScope:getFullType()].excludes[parent:getFullType()]
        and rebuilt[sideScope:getFullType()].excludes["Base.PerformanceScope1"]
        and rebuilt[parent:getFullType()].excludes[sideScope:getFullType()],
        "request-local index preserves reciprocal native mount/scope conflicts")
    function parent:getMountOn() return javaList({"Base.OtherWeapon"}) end
    rebuilt=M.candidates(weapon)
    assert(not M.isCandidate(weapon,parent:getFullType()) and not rebuilt[parent:getFullType()]
        and not rebuilt[sideScope:getFullType()].excludes[parent:getFullType()],
        "updated native MountOn remains authoritative for membership and metadata")
    api.isSlotDependent,api.getProviderUnlocks=originalDependent,originalUnlocks
    M.cache=original
end
assert(not candidates[grenade:getFullType()], "stateful launcher is conservatively left to native Gael UI")
assert(M.toolGroups("Scope",scope,false)[1][1] == ItemTag.SCREWDRIVER, "Gael native screwdriver requirement")
assert(M.toolGroups("Stool",grenade,true)[1][1] == ItemTag.SCREWDRIVER, "Gael remove screwdriver requirement")
local view = require("GMAW/Presentation").build(candidates, {}, {}, {}, player, weapon)
assert(view.bySlot.Scope and not view.bySlot.RailUp and not view.bySlot.Stool,
    "common slot UI renders Gael catalog without GoM rails or unsupported launchers")
player.hasScrewdriver=false
local denied=Authority.apply(player,{kind="install",weaponID=weapon:getID(),partID=scope:getID(),slot="Scope",fullType=scope:getFullType()})
assert(not denied and inv:contains(scope) and not weapon.parts.Scope,"server rejects missing install tool despite Gael native fallback")
player.hasScrewdriver=true
inv:Remove(carriedTool)
denied=Authority.apply(player,{kind="install",weaponID=weapon:getID(),partID=scope:getID(),slot="Scope",fullType=scope:getFullType()})
assert(not denied and not weapon.parts.Scope,"server independently checks carried tools even if native callback allows")
inv:AddItem(carriedTool)
carriedTool.isBroken=function() return true end
denied=Authority.apply(player,{kind="install",weaponID=weapon:getID(),partID=scope:getID(),slot="Scope",fullType=scope:getFullType()})
assert(not denied and not weapon.parts.Scope,"broken screwdriver never satisfies authority")
carriedTool.isBroken=function() return false end
local ok = Authority.apply(player,{kind="install",weaponID=weapon:getID(),partID=scope:getID(),slot="Scope",fullType=scope:getFullType()})
assert(ok and weapon.parts.Scope == scope and not inv:contains(scope), "Gael native authoritative install")
inv:Remove(carriedTool)
denied=Authority.apply(player,{kind="detach",weaponID=weapon:getID(),partID=scope:getID(),slot="Scope"})
assert(not denied and weapon.parts.Scope==scope,"server independently requires detach tool")
inv:AddItem(carriedTool)
player.hasScrewdriver=false
ok = Authority.apply(player,{kind="detach",weaponID=weapon:getID(),partID=scope:getID(),slot="Scope"})
assert(not ok and weapon.parts.Scope==scope, "server rejects missing detach tool")
player.hasScrewdriver=true
ok = Authority.apply(player,{kind="detach",weaponID=weapon:getID(),partID=scope:getID(),slot="Scope"})
assert(ok and not weapon.parts.Scope and inv:contains(scope), "Gael native authoritative removal")
ok = Authority.apply(player,{kind="install",weaponID=weapon:getID(),partID=grenade:getID(),slot="Stool",fullType=grenade:getFullType()})
assert(not ok and not weapon.parts.Stool and inv:contains(grenade) and grenade:getModData().grenadeRounds == 1,
    "unsupported launcher install leaves inventory and state unchanged")
weapon.parts.Stool=grenade;inv:Remove(grenade)
ok = Authority.apply(player,{kind="detach",weaponID=weapon:getID(),partID=grenade:getID(),slot="Stool"})
assert(not ok and weapon.parts.Stool==grenade and grenade:getModData().grenadeRounds==1, "unsupported launcher detach leaves state unchanged")
weapon.parts.Stool=nil;inv:AddItem(grenade)
local foreign = item("MarzGuns.Scope",999,"Scope")
function foreign:getModID() return "GunsOfMarz" end
function foreign:getMountOn() return javaList({"Base.M4"}) end
inv:AddItem(foreign)
assert(not T.compatible(foreign,weapon), "even forged MountOn cannot cross provider ownership")
ok = Authority.apply(player,{kind="install",weaponID=weapon:getID(),partID=foreign:getID(),slot="Scope",fullType=foreign:getFullType()})
assert(not ok and not weapon.parts.Scope, "server rejects GoM part on Gael")
local vanilla = item("Base.Pistol",9999)
vanilla.class="HandWeapon"
function vanilla:getModID() return "pz-vanilla" end
function vanilla:isRanged() return true end
assert(not M.supported(vanilla), "Gael owner is not the broad Base module")
if gaelRecords then
    -- Installed dependency graph plus actual Gael-patched timed actions in the
    -- complete scheduler. Only engine inventory/player objects are doubles.
    local A,S,P=require "GMAW/Actions",require "GMAW/Sources",require "GMAW/Planner"
    local ak,mount,sight=instanceItem("Base.AK47"),instanceItem("Base.AkMount"),instanceItem("Base.Accupoint")
    inv.values={ak,mount,sight}
    local screwdriver=item("Base.Screwdriver",9998)
    function screwdriver:hasTag(tag) return tag==ItemTag.SCREWDRIVER end
    inv:AddItem(screwdriver)
    for _,v in ipairs(inv.values) do
        function v:getContainer() return inv end
        function v:setJobDelta() end
        function v:setJobType() end
    end
    function inv:containsID(id) return self:getItemById(id)~=nil end
    function player:isDead() return false end
    function player:pressedCancelAction() return false end
    local originalScan=S.scan
    function S.scan()
        local scan={entries={},byID={},byType={}}
        for _,v in ipairs(inv.values) do
            local e={item=v,key="player",kind="Player"}
            scan.entries[#scan.entries+1]=e;scan.byID[v:getID()]=e
            scan.byType[v:getFullType()]={e}
        end
        return scan
    end
    local cat=M.candidates(ak)
    for _,testWeapon in ipairs({weapon,ak}) do
        local expected=M.candidates(testWeapon)
        for fullType in pairs(M.catalog()) do
            assert(M.isCandidate(testWeapon,fullType)==(expected[fullType]~=nil),
                "single-part admission matches full installed catalog: "..testWeapon:getFullType().."/"..fullType)
        end
    end
    assert(cat[sight:getFullType()].any[mount:getFullType()],"installed native dependency graph reaches planner")
    ok=Authority.apply(player,{kind="install",weaponID=ak:getID(),partID=sight:getID(),slot="Scope",fullType=sight:getFullType()})
    assert(not ok and not ak.parts.Scope,"server rejects child without mount")
    local plan=assert(P.solve(cat,{},M.availability(cat,S.scan()),{sight:getFullType()}))
    assert(#plan==2 and plan[1].slot=="Mount" and plan[2].slot=="Scope","Gael dependency-first plan")
    assert(A.begin(player,{item=ak,key="player"},"",{sight:getFullType()},P.signature(plan)))
    local queue=ISTimedActionQueue.getTimedActionQueue(player).queue
    local completed={}
    for i=1,8 do
        gmawTick()
        local action=queue[1]
        if action then
            assert(action:isValid(),"native Gael scheduled action is valid")
            completed[#completed+1]=action.part:getPartType()
            assert(action:complete())
            table.remove(queue,1);action:perform()
        end
    end
    assert(A.poll(player)=="Success" and table.concat(completed,",")=="Mount,Scope"
        and ak.parts.Mount==mount and ak.parts.Scope==sight,"scheduled Gael native mount then scope completes")
    ok=Authority.apply(player,{kind="detach",weaponID=ak:getID(),partID=mount:getID(),slot="Mount"})
    assert(not ok and ak.parts.Mount==mount,"server preserves parent supporting installed child")
    assert(Authority.apply(player,{kind="detach",weaponID=ak:getID(),partID=sight:getID(),slot="Scope"}))
    local clientMode,commands=true,0
    local originalClient=isClient
    function isClient() return clientMode end
    function sendClientCommand(who,module,command,args)
        commands=commands+1;clientMode=false
        gmawServerCommand(module,command,who,args)
        clientMode=true
    end
    plan=assert(P.solve(cat,M.installed(ak),M.availability(cat,S.scan()),{sight:getFullType()}))
    assert(A.begin(player,{item=ak,key="player"},M.fingerprint(ak),{sight:getFullType()},P.signature(plan)))
    for i=1,6 do
        gmawTick()
        local action=queue[1]
        if action then
            assert(action.complete==nil,"MP assembly sends custom authority request")
            table.remove(queue,1);action:perform()
        end
    end
    assert(commands==1 and A.poll(player)=="Success" and ak.parts.Scope==sight,
        "Gael MP queue routes one command through server native completion")
    isClient=originalClient
    S.scan=originalScan
end
providerMods={};M.cache=nil
assert(not M.enabled() and not M.supported(weapon), "neither provider disables workbench")
assert(providerForbiddenRequires == 0, "no attempted WeaponSystems/MarzWeapons require, including protected calls")
print("Gael-only: startup without Gunworks, catalog/slots, tools, authority, stateful native actions, owner isolation, no-provider")
