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
local rightFacing=false
for _,call in ipairs(scene.calls) do
    if call.name=="setViewRotation" then rightFacing=call.args[1]==-90 and call.args[2]==180 and call.args[3]==0 end
end
assert(rightFacing and scene.view=="UserDefined","Gael uses opposite side without reversing screen-up")
assert(scene.translation[1]==0.15,"Gael centering follows reversed horizontal axis")
for i=1,60 do assert(d:updateModelPreview(first,l)) end
assert(d.modelScene==scene and #scene.calls==count,"steady preview does not recreate or reconfigure the model")
scene:onMouseDown(1,1);scene:onMouseMove(20,30);scene:onMouseWheel(1)
assert(#scene.calls==count,"preview interaction cannot move rotate or zoom camera")
assert(d:updateModelPreview(gun("GoMRifle"),l),"provider-independent model swap")
assert(d.modelScene~=scene and scene.visible==false,"old model removed when selecting another weapon")
for _,call in ipairs(d.modelScene.calls) do
    if call.name=="setViewRotation" then assert(call.args[1]==90 and call.args[2]==0,"other providers retain their camera") end
end
assert(scene.calls[#scene.calls].name=="removeModel","switch releases old scene model")
assert(not d:updateModelPreview(gun("Missing"),l),"unavailable model falls back to existing icon")
assert(d:updateModelPreview(gun("EmreRifle"),l),"failed model does not poison later selections")
scene=d.modelScene
d:clearModelPreview()
assert(not d.modelScene and scene.visible==false,"close stops model rendering")
assert(w.weapons.callback==W.selectWeapon,"left weapon list remains connected to selection")
getScriptManager=manager
