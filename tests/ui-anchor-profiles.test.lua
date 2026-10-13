local Profiles=require "GMAW/UI/ProfileRegistry"
local Anchors=require "GMAW/UI/AttachmentAnchors"
local Window=require "GMAW/Window"
local Sources=require "GMAW/Sources"

local function gun(owner,name)
    return {getModID=function() return owner end,
        getStaticModel=function() return name end,
        getName=function() return name end,
        getTex=function() return name.."-texture" end,
        isTwoHandWeapon=function() return true end}
end
local gom=gun("GunsOfMarz","M4A1")
local gael=gun("GaelGunStore_B42","SVD")
local emre=gun("EmreFirearmsPack_B42","ENF2_AWP")
assert(Profiles.forWeapon(gom).id=="gom" and Profiles.forWeapon(gael).id=="gael",
    "GoM and Gael own independent visual profiles")
assert(Profiles.forWeapon(emre)==nil,
    "Emre GoM weapon-adapter bridge does not inherit GoM visual markers")
assert(Profiles.forWeapon(gun("Unknown","SVD"))==nil,
    "unregistered firearm cannot inherit another mod's visual geometry")

local function vec(x,y,z) return {x=function()return x end,y=function()return y end,z=function()return z end} end
local function script(name,positions)
    local entries={}
    for id,xyz in pairs(positions) do
        entries[#entries+1]={getId=function() return id end,
            getOffset=function() return vec(xyz[1],xyz[2],xyz[3]) end}
    end
    local map={}
    for _,entry in ipairs(entries) do map[entry:getId()]=entry end
    return {getFullType=function() return "Base."..name end,
        getAttachmentById=function(_,id) return map[id] end,
        getAttachmentCount=function() return #entries end,
        getAttachment=function(_,i) return entries[i+1] end}
end
local svd=script("SVD",{
    muzzle={0,0.6279,0.027}, Canon={0,0.5940,0.0256},
    Stock={0,0,0}, Scope={0,0.0852,0.045},
    Grip={0,0.2465,0.0067}, Laser={-0.0145,0.2884,0.0241},
    Light={0.0109,0.2758,0.025}, Handguard={0,0.1916,0.0224},
    Mount={0,0.0705,0.0233}, Barrel_Shroud={0,0.3825,0.021},
})
local m4=script("M4A1",{
    muzzle={0,0.4001,0.0258}, magazine={0,0.1030,0.0083},
    bolt_fired={0,-0.0473,0},scope={0,0.0804,0.067},
    rail_up={0,0.0870,0.0646},rail_down={0,0.2074,0.0083},
    rail_left={0.0199,0.2075,0.0257},
    rail_right={-0.0199,0.2075,0.0257},
})
local gp=Profiles.forWeapon(gael)
local mp=Profiles.forWeapon(gom)
assert(Anchors.resolve(gp,svd,"Scope").id=="Scope"
    and Anchors.resolve(gp,svd,"Grip").id=="Grip"
    and Anchors.resolve(gp,svd,"Handguard").id=="Handguard"
    and Anchors.resolve(gp,svd,"Canon").id=="Canon",
    "GGS uses actual case-sensitive weapon model attachment IDs")
assert(Anchors.resolve(mp,m4,"Scope").id=="scope"
    and Anchors.resolve(mp,m4,"Bipod").id=="rail_down"
    and Anchors.resolve(mp,m4,"Foregrip").id=="rail_down"
    and Anchors.resolve(mp,m4,"LaserRifle").id=="rail_left"
    and Anchors.resolve(mp,m4,"LightRifle").id=="rail_right",
    "GoM maps slot semantics to native rail attachment IDs")
assert(Anchors.resolve(mp,m4,"Canon").id=="muzzle",
    "GoM falls back to the actual muzzle transform when canon is absent")
assert(not Anchors.resolve(gp,svd,"Misc")
    and not Anchors.resolve(mp,m4,"Stock"),
    "missing or ambiguous attachment IDs never invent fallback positions")
local frontSling=script("FrontSling",{Sling={0,0.2,0},Stock={0,0,0}})
assert(Anchors.resolve(gp,frontSling,"Sling").id=="Stock",
    "sling uses a real rear reference instead of a crowded forward sling mount")
assert(Anchors.resolve(gp,script("RearPad",{RecoilPad={0,-0.1,0}}),"Sling").id=="RecoilPad",
    "rear recoil pad is the next sling display reference")
assert(not Anchors.resolve(gp,script("NoSling",{muzzle={0,0.5,0}}),"Sling"),
    "sling without any known reference remains a card without a line")
local poisoned=script("NaN",{Scope={0,0/0,0}})
assert(not Anchors.resolve(gp,poisoned,"Scope"),"non-finite attachment offsets rejected")
local reversedScene=ISUI3DScene:new(0,0,388,188)
reversedScene:instantiate()
reversedScene.anchorScale=1
reversedScene.anchorTranslation={x=0,y=0,z=0}
local reversedMuzzle=Anchors.project(mp,reversedScene,
    {id="muzzle",x=0,y=-0.35,z=0.02},-1)
local reversedRear=Anchors.project(mp,reversedScene,
    {id="rear",x=0,y=0,z=0},-1)
assert(reversedMuzzle and reversedRear and reversedMuzzle.x<reversedRear.x,
    "negative-axis GoM model still places the muzzle on the screen left")
local noNative=ISUI3DScene:new(0,0,388,188)
noNative:instantiate()
noNative.anchorScale=1
noNative.anchorTranslation={x=0,y=0,z=0}
noNative.javaObject.sceneToUIX=nil
assert(not Anchors.project(mp,noNative,{id="muzzle",x=0,y=0.5,z=0},1),
    "unavailable projection APIs must omit the line, never fabricate pixels")

local oldManager=getScriptManager
local oldScan=Sources.scan
getScriptManager=function()
    return {getModelScript=function(_,name)
        if name=="SVD" then return svd elseif name=="M4A1" then return m4 end
    end}
end
Sources.scan=function() return {entries={},byType={},byID={}} end
local w=Window:new(0,0,1240,850)
w.player={getPlayerNum=function()return 0 end}
w:createChildren()
local d=w.diagram
local function targetMap(weapon,slots)
    local view={slots={},bySlot={}}
    for _,slot in ipairs(slots) do
        local card={slot=slot}
        view.slots[#view.slots+1]=card
        view.bySlot[slot]=card
    end
    w.view=view
    w.target={item=weapon}
    w.activeSlot=slots[1]
    local layout=d:cardLayout()
    assert(d:updateModelPreview(weapon,layout),"model scene must be created for model-local leaders")
    local result=d:providerLeaderPoints(weapon)
    local map={}
    for index,card in ipairs(w:diagramCards()) do map[card.slot]=result[index] end
    return map,layout
end
local ggsPoints=targetMap(gael,{"Scope","Canon","Stock","Grip","Laser","Light","Handguard","Barrel_Shroud","Misc"})
assert(ggsPoints.Scope and ggsPoints.Canon and ggsPoints.Stock
    and ggsPoints.Grip and ggsPoints.Laser and ggsPoints.Light and ggsPoints.Handguard,
    "GGS script-defined locations connect to visual callouts")
assert(not ggsPoints.Misc,"missing GGS Misc attachment leaves its card without a leader")
assert(ggsPoints.Canon.x<ggsPoints.Stock.x,
    "the actual GGS muzzle projects to the LEFT of its stock")
assert(ggsPoints.Barrel_Shroud.x<ggsPoints.Scope.x
    and ggsPoints.Scope.x<ggsPoints.Stock.x,
    "front bipod, central optic and rear stock preserve their physical order")
assert(ggsPoints.Scope.y<ggsPoints.Grip.y,
    "GGS optic projects above its vertical grip")
assert(ggsPoints.Canon.id=="Canon" and ggsPoints.Scope.id=="Scope",
    "GGS uses its own named model attachment points")
local knownCount,legacyCount=0,0
d.draws={}
d:prerender()
for _,draw in ipairs(d.draws) do
    if draw.alpha==0.62 or draw.alpha==0.34 then knownCount=knownCount+1 end
end
assert(knownCount>0,"actual GGS model attachments generate visible leader segments")
local ggsCache=d.modelScene.leaderCache
assert(d:providerLeaderPoints(gael)==ggsCache.points,
    "same selected weapon reuses profile projection without rerunning Java methods")
local oldPoint=ggsCache.points[1]
d.modelScene.x=d.modelScene.x+11
local moved=d:providerLeaderPoints(gael)
assert(moved~=ggsCache.points and moved[1].x==oldPoint.x+11,
    "moving the scene without resizing invalidates panel-space endpoints")
d.modelScene.x=d.modelScene.x-11
-- Same weapon and viewport, different slot ordering: cached numeric indexes
-- must not silently assign another slot's coordinates to the selected card.
local priorView=w.view
w.view={slots={priorView.slots[3],priorView.slots[1]}}
local reordered=d:providerLeaderPoints(gael)
assert(reordered[1].id=="Stock" and reordered[2].id=="Scope",
    "slot-list refresh invalidates cached indexes even if model size is unchanged")
w.view=priorView
for _,slot in ipairs({"Stock","Scope","Canon","Barrel_Shroud","Misc"}) do
    w.activeSlot=slot;d.draws={};d:prerender()
    local count=0
    for _,draw in ipairs(d.draws) do
        assert(draw.alpha~=0.34,"unselected leaders must never be drawn")
        if draw.alpha==0.62 then count=count+1 end
    end
    assert(slot=="Misc" and count==0 or slot~="Misc" and count>0 and count<=3,
        "only the selected valid mount has a line; missing sockets have none")
end
local gomPoints=targetMap(gom,{"Scope","Canon","LaserRifle","LightRifle","Foregrip","Bipod","Stock"})
assert(gomPoints.Scope and gomPoints.Canon and gomPoints.LaserRifle and gomPoints.LightRifle
    and gomPoints.Foregrip and gomPoints.Bipod,
    "GoM sight, muzzle, rails and lower parts use model attachment data")
assert(not gomPoints.Stock,"GoM without stock attach marker suppresses that inaccurate line")
assert(gomPoints.Canon.x<gomPoints.Scope.x
    and gomPoints.Scope.y<gomPoints.Foregrip.y,
    "GoM projects muzzle-left and optic above underside rail")
assert(gomPoints.LaserRifle.id=="rail_left" and gomPoints.Bipod.id=="rail_down",
    "GoM native rail IDs remain distinguishable by logical slot")
for _,weapon in ipairs({emre,gun("Unknown","M4A1")}) do
    local pointCount=0
    for _ in pairs(d:providerLeaderPoints(weapon)) do pointCount=pointCount+1 end
    assert(pointCount==0,
        "unprofiled firearms never inherit real or placeholder leader points")
    w.target={item=weapon}
    for _,card in ipairs(w:diagramCards()) do
        w.activeSlot=card.slot;d.draws={};d:prerender()
        for _,draw in ipairs(d.draws) do
            assert(draw.alpha~=0.62 and draw.alpha~=0.34,
                "every unprofiled slot stays line-free after switching from a GoM model")
        end
        local layout=d:cardLayout()
        assert(#layout.nodes==#w:diagramCards(),"cards remain available without leaders")
    end
end
d:clearModelPreview()
Sources.scan=oldScan
getScriptManager=oldManager
