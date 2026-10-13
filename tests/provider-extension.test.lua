-- An independent system and a second gun owner sharing it. No native GoM/GGS
-- modules may be loaded; native completion doubles prove dispatch, not gameplay.
local A, M, T = require "GMAW/Adapters", require "GMAW/Model", require "GMAW/Attachments"
local P, B, V = require "GMAW/Planner", require "GMAW/Batch", require "GMAW/Presentation"
local Authority = require "GMAW/Authority"
assert(type(A.registerProvider) == "function", "independent providers need a shared registration API")
local savedMods, savedManager, savedInstance, savedType = getActivatedMods, getScriptManager, instanceItem, ItemType
local savedRequire, savedCache = require, M.cache
local active = {TestIndependentA=true, TestSharedB=true}
function getActivatedMods() return {contains=function(_,id) return active[id] == true end} end
function require(name)
    assert(not name:match("^WeaponSystems/") and not name:match("^GGS_")
        and not name:match("^FixCode/GGS_"), "A-only must not load foreign native modules: " .. name)
    return savedRequire(name)
end
ItemType={WEAPON_PART="weaponpart"}
local function gun(owner, fullType, id)
    local w=item(fullType,id); w.class="HandWeapon"; w.parts={}
    function w:getModID() return owner end
    function w:isRanged() return true end
    function w:getWeaponPart(slot) return self.parts[slot] end
    function w:getAllWeaponParts() local out={}; for _,p in pairs(self.parts) do out[#out+1]=p end; return javaList(out) end
    return w
end
local wa, wb = gun("TestIndependentA","TestA.Gun",7101), gun("TestSharedB","TestB.Gun",7102)
local unknown = gun("TestUnregistered","TestA.Gun",7103)
local function part(name,id,slot,owner)
    local p=item(name,id,slot);p.class="WeaponPart"
    function p:getModID() return owner or "TestIndependentA" end
    function p:getName() return name end
    function p:getMountOn() return javaList({"TestA.Gun","TestB.Gun"}) end
    return p
end
local mount=part("TestA.Mount",7110,"TestMount")
local replacement=part("TestA.Mount2",7111,"TestMount")
local optic=part("TestA.Optic",7112,"TestOptic")
local foreign=part("TestForeign.Optic",7113,"TestOptic","TestUnregistered")
local hidden=part("TestA.NativeOnly",7114,"TestOptic")
local parts={mount,replacement,optic,foreign,hidden}
local scripts={}
for _,p in ipairs(parts) do
    local value=p
    scripts[#scripts+1]={getModID=function() return value:getModID() end,
        getFullName=function() return value:getFullType() end,
        getObsolete=function() return false end,isItemType=function() return true end}
end
function getScriptManager() return {getAllItems=function() return javaList(scripts) end} end
function instanceItem(id) for _,p in ipairs(parts) do if p:getFullType()==id then return p end end end
M.cache=nil
assert(not M.catalog()[mount:getFullType()],"unregistered part ownership stays excluded")
local strictCalls, completed, lockOptic = 0, 0, false
local function depends(child,parent)
    return child==optic:getFullType() and (parent==mount:getFullType() or parent==replacement:getFullType())
end
A.registerProvider({attachmentSystem="test-independent-a",slots={"TestOptic","TestMount"},
    metadata=function(_,p)
        return {all={},any=p==optic and {[mount:getFullType()]=true,[replacement:getFullType()]=true} or {}}
    end,
    removable=function() return true end, depends=depends,
    selectable=function(p) return p~=hidden end,
    permanent=function(p) return lockOptic and p==optic end})
A.registerWeapon("test-independent-a-guns",{owner="TestIndependentA",requires={"TestIndependentA"},
    attachmentSystem="test-independent-a",mountOwners={TestIndependentA=true}})
A.registerPart("test-independent-a-parts",{owner="TestIndependentA",requires={"TestIndependentA"},
    attachmentSystem="test-independent-a",compatible=function() return true end,
    canPlanAttach=function() return true end,
    canAttach=function(p,_,w)
        strictCalls=strictCalls+1
        return p~=optic or w.parts.TestMount~=nil
    end,
    canDetach=function(p,_,w) return p~=w.parts.TestMount or not w.parts.TestOptic end,
    tools=function() return {} end,
    action=function(player,w,p,removing)
        return {isValid=function() return not w.rejectNative end,complete=function()
            completed=completed+1
            if removing then w.parts[p:getPartType()]=nil else w.parts[p:getPartType()]=p end
            if removing then player:getInventory():AddItem(p) else player:getInventory():Remove(p) end
            return true
        end}
    end})
assert(M.catalog()[mount:getFullType()]==mount,"late registration invalidates existing catalog")
assert(not M.catalog()[hidden:getFullType()],"provider excludes native-only parts from catalog")
assert(M.supported(wa) and M.canOpen(wa) and M.providerFor(wa)==A.provider("test-independent-a"))
local provider=A.provider("test-independent-a")
local revision=A.revision
assert(not pcall(A.registerProvider,provider),"duplicate system registration is rejected")
assert(not pcall(A.registerProvider,{attachmentSystem="test-invalid",slots={"TestNew","TestNew"},
    metadata=function() return {} end,removable=function() return true end}),"duplicate slots are rejected")
assert(A.revision==revision and not A.provider("test-invalid"),"failed registration leaves registry unchanged")
assert(not M.supported(unknown) and not T.compatible(optic,unknown),"same fullType never grants ownership")
assert(not M.supported(wb),"shared parts require an explicit weapon bridge")
A.registerWeapon("test-shared-b-guns",{owner="TestSharedB",requires={"TestSharedB","TestIndependentA"},
    attachmentSystem="test-independent-a",mountOwners={TestIndependentA=true}})
assert(M.supported(wb) and T.compatible(optic,wb),"B reuses A without importing its own parts")
assert(not T.compatible(foreign,wa) and not M.catalog()[foreign:getFullType()],"unknown parts fail closed")
local gom=gun("GunsOfMarz","TestA.Gun",7104)
assert(not T.compatible(optic,gom),"forged MountOn cannot cross attachment systems")
local cat=M.candidates(wa)
assert(not cat[hidden:getFullType()] and not M.isCandidate(wa,hidden:getFullType()),
    "provider selection policy also gates authority membership")
local originalMetadata=provider.metadata
provider.metadata=function() return {} end
local simpleCat=M.candidates(wa)
assert(not M.isMountCandidate(simpleCat,optic:getFullType()),"empty metadata supports ordinary independent slots")
assert(P.solve(simpleCat,{}, {[optic:getFullType()]={{item=optic,key="player"}}},{optic:getFullType()}),
    "empty metadata supports dependency-free planning")
provider.metadata=originalMetadata
local available={}
for fullType,c in pairs(cat) do available[fullType]={{item=c.part,key="player",kind="Player"}} end
local plan=assert(P.solve(cat,{},available,{optic:getFullType()}))
assert(#plan==2 and plan[1].slot=="TestMount" and plan[2].slot=="TestOptic","independent metadata orders parent first")
local inv=inventory({wa,wb,mount,replacement,optic})
function inv:getItemById(id) for _,p in ipairs(self.values) do if p:getID()==id then return p end end end
local player={getInventory=function() return inv end}
local view=V.build(cat,{},available,{TestOptic=optic:getFullType()},player,wa)
assert(view.bySlot.TestOptic and view.bySlot.TestMount and #view.plan==2,"new slots reach presentation without core edits")
assert(not view.bySlot.TestOptic.options[1].dim,"preview allows a queued prerequisite")
assert(T.canPlanAttach(optic,player,wa) and not T.canAttach(optic,player,wa),"preview does not weaken runtime validation")
assert(M.toolKey(optic)=="NoTools","independent tool-free parts avoid GoM tool inference")
local toolAdapter=A.part(optic)
local oldTools=toolAdapter.tools
toolAdapter.tools=function() return {{"TestHexKey"}} end
assert(M.toolKey(optic)~="Screwdriver","independent tools are not mislabeled as a screwdriver")
provider.toolKey=function() return "TestProviderHexKey" end
assert(M.toolKey(optic)=="TestProviderHexKey","provider tool labels describe its independent tool system")
toolAdapter.toolKey=function() return "TestPartHexKey" end
assert(M.toolKey(optic)=="TestPartHexKey","part-specific tool label overrides provider label")
toolAdapter.toolKey,provider.toolKey=nil,nil
toolAdapter.tools=oldTools
assert(B.preflight(player,wa,cat,plan),"independent queued parent is accepted by preflight")
local ok=Authority.apply(player,{kind="install",weaponID=wa:getID(),partID=optic:getID(),slot="TestOptic",fullType=optic:getFullType()})
assert(not ok and completed==0,"server rejects child before its native prerequisite exists")
wa.rejectNative=true
ok=Authority.apply(player,{kind="install",weaponID=wa:getID(),partID=mount:getID(),slot="TestMount",fullType=mount:getFullType()})
assert(not ok and completed==0,"server respects native action validity")
wa.rejectNative=false
ok=Authority.apply(player,{kind="install",weaponID=wa:getID(),partID=mount:getID(),slot="Scope",fullType=mount:getFullType()})
assert(not ok and completed==0,"client cannot place an independent part into a forged slot")
for _,p in ipairs({mount,optic}) do
    assert(Authority.apply(player,{kind="install",weaponID=wa:getID(),partID=p:getID(),slot=p:getPartType(),fullType=p:getFullType()}))
end
assert(completed==2 and strictCalls>0 and wa.parts.TestOptic==optic,"unchanged authority dispatches independent native completion")
-- Batch only computes order. The native detach callback must support preflight
-- while the descendant is still installed; runtime action revalidates each step.
local adapter=A.part(mount)
local oldDetach=adapter.canDetach
adapter.canDetach=function() return true end
local replacementPlan=assert(P.solve(cat,M.installed(wa),available,{replacement:getFullType()}))
lockOptic=true
assert(not B.preflight(player,wa,cat,replacementPlan),"provider permanent part blocks dependent parent replacement")
ok=Authority.apply(player,{kind="detach",weaponID=wa:getID(),partID=optic:getID(),slot="TestOptic"})
assert(not ok and wa.parts.TestOptic==optic,"provider permanent policy reaches unchanged authority")
lockOptic=false
local order=assert(B.preflight(player,wa,cat,replacementPlan))
assert(#order.detached==2 and order.detached[1].part==optic and order.detached[2].part==mount,
    "provider dependencies detach children before replaced mount")
assert(wa.parts.TestMount==mount and wa.parts.TestOptic==optic,"preflight is read-only")
adapter.canDetach=oldDetach
ok=Authority.apply(player,{kind="detach",weaponID=wa:getID(),partID=mount:getID(),slot="TestMount"})
assert(not ok and wa.parts.TestMount==mount,"strict native parent removal protects attached child")
for _,p in ipairs({optic,mount}) do
    assert(Authority.apply(player,{kind="detach",weaponID=wa:getID(),partID=p:getID(),slot=p:getPartType()}))
end
assert(not wa.parts.TestOptic and not wa.parts.TestMount and completed==4,
    "unchanged authority uses independent native removal after ordered child removal")
A.registerWeapon("test-unknown-system",{owner="TestUnregistered",requires={"TestIndependentA"},
    attachmentSystem="test-missing-provider",matches=function() return true end})
assert(not M.supported(unknown),"weapon registration without provider fails closed")
active={TestSharedB=true}
assert(not M.supported(wb),"bridge fails closed when A is inactive")
getActivatedMods,getScriptManager,instanceItem,ItemType=savedMods,savedManager,savedInstance,savedType
require=savedRequire
M.cache=savedCache
