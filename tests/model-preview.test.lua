local W,S=require "GMAW/Window",require "GMAW/Sources"
local scan=S.scan
S.scan=function() return {entries={},byID={},byType={}} end
local w=W:new(0,0,1120,820)
w.player={getPlayerNum=function() return 0 end}
w:createChildren();S.scan=scan
local manager=getScriptManager
function getScriptManager() return {getModelScript=function(_,name)
    if name=="Missing" then return nil end
    return {getFullType=function() return "Base."..name end}
end} end
local function gun(name,owner)
    return {getStaticModel=function() return name end,isTwoHandWeapon=function() return true end,
        getModID=function() return owner end}
end
local d=w.diagram
local l=d:cardLayout()
local first=gun("SVD","GaelGunStore_B42")
assert(d:updateModelPreview(first,l),"known model renders")
local scene=d.modelScene
local count=#scene.calls
local staticView=false
for _,call in ipairs(scene.calls) do
    if call.name=="setView" then staticView=call.args[1]=="Right" end
    assert(call.name~="setViewRotation","must not animate camera to a UserDefined angle")
end
assert(staticView and scene.view=="Right","native Right camera is the default, with no 350ms interpolation")
assert(scene.translation[1]==0 and scene.translation[2]==0 and scene.translation[3]==0,
    "models without usable attachments start at the scene origin")
assert(scene.modelRotation[1]==-90 and scene.modelRotation[2]==0 and scene.modelRotation[3]==0,
    "common held-model axis maps local muzzle Y left and local Z upright")
for i=1,60 do assert(d:updateModelPreview(first,l)) end
assert(d.modelScene==scene and #scene.calls==count,"steady preview does not recreate or reconfigure the model")
scene:onMouseDown(1,1);scene:onMouseMove(20,30);scene:onMouseWheel(1)
assert(#scene.calls==count,"preview interaction cannot move rotate or zoom camera")
assert(d:updateModelPreview(gun("GoMRifle"),l),"provider-independent model swap")
assert(d.modelScene~=scene and scene.visible==false,"old model removed when selecting another weapon")
for _,call in ipairs(d.modelScene.calls) do
    assert(call.name~="setViewRotation","provider swaps never cause a rotating camera transition")
    if call.name=="setView" then assert(call.args[1]=="Right","all providers use the static native Right view") end
    if call.name=="setModelUseWorldAttachment" or call.name=="setModelWeaponRotationHack" then
        assert(call.args[2]==false,"floor rotation and implicit weapon hack disabled")
    end
end
assert(d.modelScene.modelRotation[1]==-90 and d.modelScene.modelRotation[3]==0,
    "GoM muzzle uses the same left-facing profile as Gael")
assert(scene.calls[#scene.calls].name=="removeModel","switch releases old scene model")
assert(not d:updateModelPreview(gun("Missing"),l),"unavailable model falls back to existing icon")
assert(d:updateModelPreview(gun("EmreRifle"),l),"failed model does not poison later selections")
scene=d.modelScene
assert(scene.modelRotation[1]==-90 and scene.modelRotation[3]==0,
    "Emre muzzle uses the same left-facing profile")
d:clearModelPreview()
assert(not d.modelScene and scene.visible==false,"close stops model rendering")
assert(w.weapons.callback==W.selectWeapon,"left weapon list remains connected to selection")
getScriptManager=manager

-- Common attachment-derived framing, independent of provider/model origin.
local function vec(x,y,z) return {x=function() return x end,y=function() return y end,z=function() return z end} end
local function attachment(id,x,y,z,rx,ry,rz)
    return {getId=function() return id end,getOffset=function() return vec(x,y,z) end,
        getRotate=function() return vec(rx or 0,ry or 0,rz or 0) end}
end
local function model(points,world)
    return {getAttachmentCount=function() return #points end,getAttachment=function(_,i) return points[i+1] end,
        getAttachmentById=function(_,id)
            if id=="world" then return world end
            for _,a in ipairs(points) do if a:getId()==id then return a end end
        end}
end
for _,origin in ipairs({-0.7,0,0.9}) do
    local b=d:modelFrame(model({attachment("stock",0,origin,0),attachment("muzzle",0,origin+1,0),
        attachment("scope",0,origin+0.3,0.2)}))
    assert(b and math.abs(b.right-b.left-1)<0.00001,"offset origin does not affect fitted length")
    local preview=ISUI3DScene:new(0,0,324,140);preview:instantiate();preview.frameBounds=b
    d:fitModelPreview(preview)
    local scale=preview.modelScale[1]
    local envelope=d:modelEnvelope(b)
    assert(preview.translation[1]==0,"world X points into the camera, not sideways")
    assert(math.abs((envelope.left+envelope.right)/2*scale-preview.translation[3])<0.00001,
        "horizontal center uses WORLD Z under the default Right camera")
    assert(math.abs((envelope.bottom+envelope.top)/2*scale+preview.translation[2])<0.00001,
        "vertical center uses WORLD Y and preserves the sights-up orientation")
    local pixels=324/1366*math.exp(2.6)*160/1.82
    assert((envelope.right-envelope.left)*scale*pixels<=324*0.86+0.001,
        "silhouette envelope width stays inside the scene")
    assert(math.max(envelope.top-envelope.bottom,(envelope.right-envelope.left)*0.30)*scale*pixels<=140*0.86+0.001,
        "silhouette envelope height stays inside the scene")
    local calls=#preview.calls;d:fitModelPreview(preview)
    assert(#preview.calls==calls,"framing never repeats on steady frames")
    preview.height=80;d:fitModelPreview(preview)
    assert(#preview.calls>calls and preview.modelScale[1]<scale,"resize refits height without reloading model")
end
-- Emre AWP is the user-reported live failure: only its stock showed at the
-- right edge. Its actual installed model has muzzle Y=.5781, magazine Y=.103473.
-- The mesh extends behind the magazine, so these points are not mesh bounds.
local awp=model({attachment("muzzle",0,0.5781,0.0476),
    attachment("magazine",0,0.10347318,0.03720255)})
local awpBounds=assert(d:modelFrame(awp))
local awpEnvelope=d:modelEnvelope(awpBounds)
assert(awpEnvelope.left<0 and awpEnvelope.right>0.5781,
    "AWP fitting reserves stock and muzzle clearance outside mounting points")
local awpScene=ISUI3DScene:new(0,0,388,188);awpScene:instantiate()
awpScene.frameBounds=awpBounds
d:fitModelPreview(awpScene)
local ppu=awpScene.width/1366*math.exp(2.6)*160/1.82
local function projected(x,y,z,dir,scene)
    return (scene.translation[3]-y*dir*scene.modelScale[1])*ppu,
        (z*scene.modelScale[1]+scene.translation[2])*ppu
end
local stockX,stockY=projected(0,-0.26,-0.07,1,awpScene)
local muzzleX,muzzleY=projected(0,0.5781,0.0476,1,awpScene)
local _,sightY=projected(0,0.15,0.15,1,awpScene)
local _,gripY=projected(0,0.15,-0.15,1,awpScene)
assert(stockX>muzzleX and math.abs(stockX)<188 and math.abs(muzzleX)<188,
    "AWP stock and left-facing muzzle both fit in its 388px preview")
assert(math.abs(stockY)<91 and math.abs(muzzleY)<91
    and sightY>gripY and math.abs(sightY)<91 and math.abs(gripY)<91,
    "AWP sights stay above the grip, inside the 188px preview")
local rotated=d:modelFrame(model({attachment("stock",0,0,0),attachment("muzzle",0,1,0)},attachment("world",7,8,9,0,180,90)))
assert(rotated and rotated.left==0 and rotated.right==1,"floor position and rotation cannot change framing")
local reversed=model({attachment("stock",0,0,0),attachment("muzzle",0,-1,0)})
local reversedFrame=d:modelFrame(reversed)
assert(d:modelDirection(reversed)==-1 and reversedFrame.left==0 and reversedFrame.right==1,
    "negative barrel-axis definition is normalized to the same horizontal direction")
local nativeManager=getScriptManager
getScriptManager=function() return {getModelScript=function()
    return {getFullType=function() return "Base.Reversed" end,
        getAttachmentCount=reversed.getAttachmentCount,
        getAttachment=reversed.getAttachment,
        getAttachmentById=reversed.getAttachmentById}
end} end
assert(d:updateModelPreview(gun("Reverse"),l),"reversed-barrel test model creates a scene")
local reverseScene=d.modelScene
assert(reverseScene.modelRotation[1]==-90 and reverseScene.modelRotation[2]==0
    and reverseScene.modelRotation[3]==180 and reverseScene.view=="Right",
    "opposite Y muzzle rotates locally without flipping sights or moving the camera")
local reverseMuzzleX=reverseScene.translation[3]-reverseScene.modelScale[1]
local reverseRearX=reverseScene.translation[3]
assert(reverseMuzzleX<reverseRearX,"normalized negative-Y muzzle projects LEFT under Right camera")
d:clearModelPreview()
getScriptManager=nativeManager
local offsetOrigin=model({attachment("Stock",0,1.0,0),attachment("muzzle",0,0.45,0),
    attachment("Grip",0,0.8,0)})
assert(d:modelDirection(offsetOrigin)==-1
    and math.abs(d:modelFrame(offsetOrigin).right-d:modelFrame(offsetOrigin).left-0.55)<0.00001,
    "rear attachment determines direction when all offsets are positive")
assert(not d:modelFrame(model({attachment("world",9,9,9)})),"world marker alone is not a gun extent")
assert(not d:modelFrame(model({attachment("muzzle",0,0,0)})),"insufficient points retain fallback framing")
-- Representative installed script coordinates (not copied meshes/assets).
local samples={
    {name="Gael SVD",points={attachment("muzzle",0,0.6279,0.027),attachment("Stock",0,0,0),attachment("Grip",0,0.2465,0.0067)},world=attachment("world",-0.03,0,0)},
    {name="GoM M4A1",points={attachment("muzzle",0,0.4001,0.0258),attachment("bolt_fired",0,-0.0473,0),attachment("scope",0,0.0804,0.067)},world=attachment("world",0.02,0.13,0,180,0,180)},
    {name="emre M4A1",points={attachment("muzzle",-0.0041,0.3999,0.0266),attachment("magazine",0,0,0)}},
    {name="emre M16A1",points={attachment("muzzle",0,0.4331,0.0266),attachment("stock",0,-0.0003,0.0002),attachment("scope",0,0.0752,0.062)},world=attachment("world",-0.024384160,0.123788260,-0.036314336,0,180,90)},
    {name="GoM M16A2",points={attachment("muzzle",0,0.4966,0.0247),attachment("bolt_fired",0,-0.047,0),attachment("magazine",0,0.103,0.0083)},world=attachment("world",0.02,0.13,0,180,0,180)}
}
for _,sample in ipairs(samples) do
    local bounds=d:modelFrame(model(sample.points,sample.world))
    assert(bounds and bounds.right>bounds.left,sample.name.." supports shared estimated framing")
    local withoutWorld=d:modelFrame(model(sample.points))
    assert(bounds.left==withoutWorld.left and bounds.right==withoutWorld.right
        and bounds.top==withoutWorld.top and bounds.bottom==withoutWorld.bottom,sample.name.." independent of floor pose")
end

-- M92FS uses negative local Z for the slide/sights, positive Z for the heel.
-- Correct that authored up axis while preserving left-facing muzzle and camera.
local Anchors=require "GMAW/UI/AttachmentAnchors"
local GoMProfile=require "GMAW/UI/Profiles/GoM"
local pistol=model({attachment("muzzle",0,0.1433,-0.034),
    attachment("stock",0,-0.0137,0.0634),attachment("scope",0,0.0841,-0.0484),
    attachment("underbarrel",0,0.1075,-0.0132),attachment("canon",0,0.1406,-0.0337)})
pistol.getFullType=function() return "MarzGuns.M92FS" end
local pistolManager=getScriptManager
getScriptManager=function() return {getModelScript=function() return pistol end} end
for _,owner in ipairs({"GunsOfMarz","MarzGuns"}) do
    assert(d:updateModelPreview(gun("M92FS",owner),l))
    local s=d.modelScene
    assert(s.modelRotation[1]==-90 and s.modelRotation[2]==180 and s.modelRotation[3]==0
        and s.anchorUpSign==-1 and s.view=="Right","GoM handgun corrects up, not camera or muzzle direction")
    local function point(slot)
        return assert(Anchors.project(GoMProfile,s,assert(Anchors.resolve(GoMProfile,pistol,slot)),1))
    end
    local muzzle,heel,sight,lower=point("Canon"),point("Stock"),point("Scope"),point("Underbarrel")
    assert(muzzle.x<heel.x,"M92FS muzzle remains left of its grip heel")
    assert(sight.y<lower.y and lower.y<heel.y,"M92FS sight above barrel underside, heel below both")
    local b=d:modelFrame(pistol,-1)
    assert(b.top>0 and b.bottom<0,"handgun frame follows its corrected up axis")
end
for _,name in ipairs({"TEC9","MP5K","MAC10","M92FS","M93R","USP","DEAGLE","HIPOWER","P226","M1911",
    "VP70M","SW629","MP412","RHINO","COLT_SINGLE","PYTHON","DETECTIVE_38"}) do
    local script={getFullType=function() return "MarzGuns."..name end}
    assert(d:modelUpSign(gun(name,"GunsOfMarz"),script)==-1,"verified handgun axis: "..name)
    assert(d:modelUpSign(gun(name,"EmreFirearmsPack_B42"),script)==1
        and d:modelUpSign(gun(name,"GaelGunStore_B42"),script)==1,
        "same model name from a different owner must not inherit GoM axes")
end
assert(d:modelUpSign(gun("M16A2","GunsOfMarz"),
    {getFullType=function() return "MarzGuns.M16A2" end})==1,"GoM rifles keep their existing up axis")
assert(d:modelUpSign(gun("M92FS","GunsOfMarz"),
    {getFullType=function() return "Other.M92FS" end})==1,"handgun axis override requires the verified model namespace")
d:clearModelPreview()
getScriptManager=pistolManager

-- Owner-specific anchor profiles are optional: GGS, Emre and future providers
-- must all reach the same installed-part renderer and enlarged default frame.
local bridgeManager=getScriptManager
local bridgeBody={size=function() return 2 end,get=function()
    return "item Rifle { ModelWeaponPart = Optic OpticModel mount Scope, }"
end}
local bridgeScript={getFullName=function() return "FutureArms.Rifle" end,
    getLoadedScriptBodies=function() return bridgeBody end}
local bridgePart={getFullType=function() return "FutureArms.Optic" end}
getScriptManager=function() return {getModelScript=function(_,name)
    return {getFullType=function() return name end,
        getAttachmentCount=function() return 2 end,
        getAttachment=function(_,index)
            return index==0 and attachment("stock",0,-0.1,0) or attachment("muzzle",0,0.5,0.04)
        end}
end} end
local sharedScale
for _,owner in ipairs({"GaelGunStore_B42","EmreFirearmsPack_B42","FutureUnregisteredOwner"}) do
    local item=gun("FutureArms.Rifle",owner)
    item.getScriptItem=function() return bridgeScript end
    item.getAllWeaponParts=function() return {size=function() return 1 end,get=function() return bridgePart end} end
    assert(d:updateModelPreview(item,l))
    local preview=d.modelScene
    assert(#preview.installedModelIds==1,owner.." renders installed part without a GoM dependency")
    assert(not preview.framing,owner.." uses common default without a per-owner scale table")
    if sharedScale then assert(math.abs(preview.anchorScale-sharedScale)<0.000001,"same geometry uses same scale across owners") end
    sharedScale=preview.anchorScale
    local callCount=#preview.calls
    for i=1,10 do assert(d:updateModelPreview(item,l)) end
    assert(#preview.calls==callCount,"unknown/known owners avoid steady-state native rebuilds")
end
d:clearModelPreview()
getScriptManager=bridgeManager

-- GoM AR15 measured BODY is much shallower than the generic silhouette
-- estimate. Enlarge within its existing viewport, keeping barrel/stock room.
local ar15=model({attachment("muzzle",0,0.4966,0.0247),
    attachment("bolt_fired",0,-0.047,0),attachment("scope",0,0.0804,0.067)})
local arBounds=d:modelFrame(ar15)
local generic=ISUI3DScene:new(0,0,550,140);generic:instantiate();generic.frameBounds=arBounds
generic.framing={down=0.24,up=0.18,minDown=0.11,minUp=0.11,minAspect=0.47}
d:fitModelPreview(generic)
local gom=ISUI3DScene:new(0,0,550,140);gom:instantiate();gom.frameBounds=arBounds
gom.framing=GoMProfile.framing
d:fitModelPreview(gom)
assert(gom.modelScale[1]>generic.modelScale[1]*1.3,"common preview recovers at least 30 percent scale in shallow viewport")
local oldEnvelope,newEnvelope=d:modelEnvelope(arBounds,generic.framing),d:modelEnvelope(arBounds)
assert(oldEnvelope.left==newEnvelope.left and oldEnvelope.right==newEnvelope.right,
    "larger GoM preview retains conservative stock and full barrel clearance")
assert(newEnvelope.bottom< -0.0677 and newEnvelope.top>0.0718,"measured AR15 BODY remains inside frame")
assert(d:modelEnvelope(arBounds).top==newEnvelope.top,"unknown providers inherit enlarged common framing")
for _,sample in ipairs({
    {name="MP5K",muzzle=0.228,scope=-0.0693,bottom=-0.1021,top=0.1434},
    {name="TEC9",muzzle=0.2163,scope=-0.0406,bottom=-0.0804,top=0.0596},
}) do
    local bounds=d:modelFrame(model({attachment("muzzle",0,sample.muzzle,0),
        attachment("magazine",0,0,0),attachment("scope",0,0.08,sample.scope)}),-1)
    local before=d:modelEnvelope(bounds)
    local after=d:modelEnvelope(bounds,GoMProfile.modelFraming[sample.name])
    assert(after.top-after.bottom<before.top-before.bottom,sample.name.." compact frame also grows the model")
    assert(after.bottom<sample.bottom and after.top>sample.top,sample.name.." measured composed geometry fits")
end

-- A stateful firearm may change its base model without changing item identity.
local changingName="First"
local changing=gun("unused")
changing.getStaticModel=function() return changingName end
getScriptManager=function() return {getModelScript=function(_,name)
    return {getFullType=function() return "Base."..name end}
end} end
assert(d:updateModelPreview(changing,l))
local oldScene=d.modelScene
changingName="Second"
assert(d:updateModelPreview(changing,l) and d.modelScene~=oldScene and not oldScene.visible,
    "same item with changed static model releases and rebuilds preview")
d:clearModelPreview()
getScriptManager=pistolManager
