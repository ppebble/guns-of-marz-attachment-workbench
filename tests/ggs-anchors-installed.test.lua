-- Every managed slot of every installed GGS firearm. Fixtures are generated
-- locally from read-only upstream metadata; no upstream assets are packaged.
local Anchors=require "GMAW/UI/AttachmentAnchors"
local Profile=require "GMAW/UI/Profiles/Gael"
local Window=require "GMAW/Window"
local Sources=require "GMAW/Sources"
local oldManager,oldScan=getScriptManager,Sources.scan
local currentScript
getScriptManager=function() return {getModelScript=function() return currentScript end} end
Sources.scan=function() return {entries={},byType={},byID={}} end
local w=Window:new(0,0,1240,850)
w.player={getPlayerNum=function() return 0 end}
w:createChildren()
local d=w.diagram
local pairsChecked,missing,rearSling,selectedChecked=0,0,0,0
for _,record in ipairs(assert(GGSAnchorFixtures)) do
    local map,entries={},{}
    for id,xyz in pairs(record.attachments) do
        local key,position=id,xyz
        local attachment={getId=function() return key end,
            getOffset=function() return {
                x=function() return position[1] end,
                y=function() return position[2] end,
                z=function() return position[3] end} end}
        map[id]=attachment;entries[#entries+1]=attachment
    end
    currentScript={getFullType=function() return record.model end,
        getAttachmentById=function(_,id) return map[id] end,
        getAttachmentCount=function() return #entries end,
        getAttachment=function(_,i) return entries[i+1] end}
    local gun={getModID=function() return "GaelGunStore_B42" end,
        getStaticModel=function() return record.model end,
        getName=function() return record.weapon end,
        isTwoHandWeapon=function() return true end}
    local slots={}
    for slot in pairs(record.slots) do slots[#slots+1]=slot end
    table.sort(slots)
    w.view={slots={}}
    for _,slot in ipairs(slots) do w.view.slots[#w.view.slots+1]={slot=slot} end
    w.target={item=gun}
    assert(d:updateModelPreview(gun,d:cardLayout()),record.weapon.." preview")
    local scene=d.modelScene
    local direction=d:modelDirection(currentScript)
    local ppu=scene.width/1366*math.exp(2.6)*160/1.82
    for slot,nativeId in pairs(record.slots) do
        pairsChecked=pairsChecked+1
        local expected=nativeId
        if slot=="Sling" then
            expected=map.Stock and "Stock" or map.RecoilPad and "RecoilPad" or nativeId
            if expected and expected~="Sling" then rearSling=rearSling+1 end
        end
        local attachment=Anchors.resolve(Profile,currentScript,slot)
        if not expected then
            assert(not attachment,record.weapon.." must omit missing "..slot)
            missing=missing+1
        else
            assert(attachment and attachment.id==expected,record.weapon.." socket "..slot)
            local p=assert(Anchors.project(Profile,scene,attachment,direction),record.weapon.." project "..slot)
            local xyz=record.attachments[expected]
            local x=scene.width/2+(scene.anchorTranslation.z-direction*xyz[2]*scene.anchorScale)*ppu
            local y=scene.height/2-(scene.anchorTranslation.y+xyz[3]*scene.anchorScale)*ppu
            assert(math.abs(p.x-x)<=0.501 and math.abs(p.y-y)<=0.501,
                record.weapon.." native Right projection "..slot)
        end
    end
    local points=d:providerLeaderPoints(gun)
    for i,card in ipairs(w:diagramCards()) do
        w.activeSlot=card.slot;d.draws={};d:prerender()
        local count=0
        for _,draw in ipairs(d.draws) do
            assert(draw.alpha~=0.34,"unselected line on "..record.weapon)
            if draw.alpha==0.62 then count=count+1 end
        end
        assert(points[i] and count>0 and count<=3 or not points[i] and count==0,
            record.weapon.." selected-only line "..card.slot)
        selectedChecked=selectedChecked+1
    end
end
d:clearModelPreview()
getScriptManager,Sources.scan=oldManager,oldScan
assert(pairsChecked>0 and selectedChecked>0,"installed audit must not pass with no fixtures")
print("PASS GGS all-slot projection: "..pairsChecked.." pairs, "..missing.." omitted, "
    ..rearSling.." rear sling references, "..selectedChecked.." selected-card checks")
