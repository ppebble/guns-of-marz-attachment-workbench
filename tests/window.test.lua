local W = require "GMAW/Window"
local M, S = require "GMAW/Model", require "GMAW/Sources"
local saved = {supported=M.supported,canOpen=M.canOpen,candidates=M.candidates,scan=S.scan,toolKey=M.toolKey}
local gun=item("gun",900); gun.getName=function() return "Gun" end; gun.getTex=function() return "gun-icon" end
gun.getAllWeaponParts=function() return javaList({}) end
local function part(name,id,slot)
    local p=item(name,id,slot); p.getName=function() return name end; p.getTex=function() return name.."-icon" end; return p
end
local rail,scope,missing=part("rail",1,"RailUp"),part("scope",2,"Scope"),part("missing",3,"Scope")
scope.getPartType=function() return "Scope" end
scope.getFullType=function() return "MarzGuns.OKP3_Sight" end
scope.getModID=function() return "GunsOfMarz" end
scope.getDamage=function() return 0.5 end
scope.getMaxRange=function() return 4 end
scope.getMountOn=function() return javaList({"MarzGuns.M16A1", "MarzGuns.M16A2"}) end
local catalog={rail={slot="RailUp",part=rail,all={},any={},consume="rail"},
    scope={slot="Scope",part=scope,all={},any={},consume="scope"},missing={slot="Scope",part=missing,all={},any={},consume="missing"}}
ItemTag={SCREWDRIVER="screwdriver",WRENCH="wrench",PIPE_WRENCH="pipe_wrench"}
local screwdriver=part("screwdriver",44,"Tool"); screwdriver.getTex=function() return "screwdriver-icon" end
screwdriver.hasTag=function(_,tag) return tag==ItemTag.SCREWDRIVER end
local brokenWrench=part("wrench",45,"Tool"); brokenWrench.isBroken=function() return true end
brokenWrench.hasTag=function(_,tag) return tag==ItemTag.WRENCH end
-- Tools are deliberately outside the player inventory: the same nearby scan
-- drives both display and queued transfer.
local scan={entries={{item=gun,kind="Player",key="player"},{item=screwdriver,kind="Furniture",key="nearby"},{item=brokenWrench,kind="Floor",key="nearby"}},
    byType={rail={{item=rail,key="player",kind="Player"}},scope={{item=scope,key="floor",kind="Floor"}}}}
M.supported=function() return true end; M.canOpen=function() return true end; M.candidates=function() return catalog end
M.toolKey=function() return "Tools" end; S.scan=function() return scan end
local player={getPlayerNum=function() return 0 end,getInventory=function() return inventory({}) end}
local originalGetCore=getCore
getCore=function() return {getScreenWidth=function() return 1920 end,getScreenHeight=function() return 1080 end} end
W.open(player,gun)
getCore=originalGetCore
local w=assert(GMAWWindows[0])
assert(w.width==1240 and w.height==850,
    "workbench expands only modestly at desktop resolution")
assert(w.weapons.width>0 and w.slots.width>0 and w.mounts.width>0 and w.parts.width>0)
assert(w.searchEntry.y < w.weapons.y and w.searchEntry.placeholder == "Search")
assert(w.screwdriver and w.screwdriver.item==screwdriver and w.wrench==nil,
    "working nearby screwdriver is enabled; broken nearby wrench is disabled")
assert(w.weapons.x+w.weapons.width<w.slots.x and w.slots.x+w.slots.width<w.mounts.x)
assert(w.diagram.width == w.slots.width and w.diagram.y < w.slots.y,
    "weapon diagram sits above the complete scrolling slot list")
assert(w.mounts.width == w.optionsWidth and w.parts.width == w.optionsWidth
    and w.mounts.y < w.parts.y, "mounts and selected-slot options share the right column")
local formerRightWidth = w.width - (20 + w.leftWidth + math.floor((w.width - 40) * 0.39) + 10) - 10
assert(w.optionsWidth <= formerRightWidth * 0.71 and w.middleWidth > w.optionsWidth,
    "right column shrinks by about 30 percent in favor of the weapon diagram")
assert(w.diagram.height > 300 and w.slots.height >= w.slots.itemheight,
    "weapon diagram grows until the complete slot list shows three rows")
assert(#w.slots.items==2 and #w.mounts.items==1 and w.mounts.items[1].item.item==rail)
local installedOption = {current=true, quantity=0, fullType="rail", item=rail}
local installedTooltip
w:addOption({items={}, addItem=function(_, _, _, tooltip) installedTooltip=tooltip end}, installedOption)
assert(installedOption.subtitle == "Installed", "installed status must not imply zero installed parts")
assert(string.find(installedTooltip, "Available  x0", 1, true), "tooltip keeps the separate spare-part quantity")
w:selectSlot(w.view.bySlot.Scope)
assert(w:diagramCards()[1].slot == "Scope", "priority slot appears in diagram")
local quickX, quickY = w.diagram:cardRect(1)
w.diagram:onMouseDown(quickX + 8, quickY + 8)
assert(w.activeSlot == "Scope", "diagram card selects the same slot as the complete list")
assert(w.slots.items[w.slots.selected].item.slot == "Scope", "diagram selection highlights the complete list")
local fullWidth = w.diagram.width
w.diagram.width = 300
assert(#w:diagramCards() == 1, "prerequisite rails merge into attachment nodes")
w.diagram.width = fullWidth
local originalView = w.view
local many = {slots={},bySlot={}}
for _,slot in ipairs(M.slots) do
    local card = {slot=slot}
    many.slots[#many.slots + 1] = card; many.bySlot[slot] = card
end
w.view = many
assert(#w:diagramCards() == #M.slots - 6, "only six prerequisite slots merge into attachment nodes")
local function checkDiagram(window)
    local d, cards = window.diagram, window:diagramCards()
    local originalSelect = window.selectSlot
    local clicked = {}
    window.selectSlot = function(_, card) clicked[card.slot] = true end
    local layout = d:cardLayout()
    assert(layout.gun.width >= d.width * 0.60 and layout.gun.height >= 56,
        "firearm remains a large central image")
    local bounds = {}
    for index, card in ipairs(cards) do
        local x,y,width,height = d:cardRect(index, layout)
        assert(x, "every supported attachment visible immediately: "..card.slot)
        if x then
            assert(x >= 0 and y >= 0 and x + width <= d.width and y + height <= d.height,
                string.format("out of panel %s at %.1f,%.1f size %.1fx%.1f panel %dx%d",
                    card.slot,x,y,width,height,d.width,d.height))
            assert(height >= layout.fontHeight + 6)
            assert(x+width<=layout.gun.x or x>=layout.gun.x+layout.gun.width
                or y + height <= layout.gun.y or y >= layout.gun.y + layout.gun.height,
                "cards never cover the central firearm")
            for _,other in ipairs(bounds) do
                assert(x + width <= other.x or other.x + other.width <= x
                    or y + height <= other.y or other.y + other.height <= y,
                    "spatial slot hit targets never overlap")
            end
            bounds[#bounds+1] = {x=x,y=y,width=width,height=height,elbowY=layout.nodes[index].elbowY}
            assert(d:onMouseDown(x + width/2, y + height/2))
            assert(clicked[card.slot], "click selects exact provider slot")
            local n = layout.nodes[index]
            assert(n.side or n.top and n.elbowY < layout.gun.y
                or not n.top and n.elbowY > layout.gun.y + layout.gun.height,
                "horizontal connector stays outside firearm")
        end
    end
    window.selectSlot = originalSelect
    return layout
end
local stable=checkDiagram(w)
w.activeSlot="Clip"
assert(w.diagram:cardLayout()==stable, "selection never recomputes spatial positions")
w.diagram.width=300
checkDiagram(w)
w.diagram.width=fullWidth
local previousActive = w.activeSlot
w.activeSlot = many.slots[#many.slots].slot
w.diagram:prerender()
assert(w.diagram:cardRect(#w:diagramCards()), "last actual attachment is present without promotion")
w.activeSlot = previousActive
local spatial={slots={},bySlot={}}
for _,slot in ipairs({"Scope","Stock","RailUp","Canon","LaserRifle","Foregrip","LightRifle","Bipod"}) do
    local card={slot=slot}; spatial.slots[#spatial.slots+1]=card; spatial.bySlot[slot]=card
end
w.view=spatial
local geometry=checkDiagram(w)
-- Only the selected card draws a leader; other cards remain clickable.
-- The former 5x5 orange marker must never return: it suggested exact
-- attachment coordinates that the model data cannot always provide.
w.activeSlot="Scope"
-- Shared attachment rules do not imply shared geometry. Emre without its
-- own visual profile must draw no lines, even for the selected card.
local formerOwner=gun.getModID
gun.getModID=function() return "EmreFirearmsPack_B42" end
w.diagram.draws={}
w.diagram:prerender()
local selectedLeaders,mutedLeaders=0,0
for _,draw in ipairs(w.diagram.draws) do
    if draw.alpha==0.62 then selectedLeaders=selectedLeaders+1 end
    if draw.alpha==0.34 then mutedLeaders=mutedLeaders+1 end
    if draw.x and draw.width==5 and draw.height==5 then
        for _,node in pairs(geometry.nodes) do
            assert(not(draw.x==node.anchorX-2 and draw.y==node.anchorY-2),
                "an approximate anchor must not draw a square endpoint marker")
        end
    end
    if (draw.alpha==0.62 or draw.alpha==0.34) and draw.width==1 and draw.height==1 then
        error("zero-length connector must not draw a 1-pixel dot")
    end
end
assert(selectedLeaders==0 and mutedLeaders==0,
    "unprofiled Emre draws neither selected nor unselected placeholder leaders")
gun.getModID=formerOwner
w.diagram.draws={}
w.diagram:prerender()
for _,draw in ipairs(w.diagram.draws) do
    assert(draw.alpha~=0.62 and draw.alpha~=0.34,
        "GoM with no model attachment coordinates omits old fake leaders")
end
local nodesBySlot={}
for i,card in ipairs(w:diagramCards()) do nodesBySlot[card.slot]=geometry.nodes[i] end
assert(nodesBySlot.Stock.side=="right" and nodesBySlot.Canon.side=="left",
    "only rear and muzzle cards occupy the physical ends")
for _,slot in ipairs({"LaserRifle","LightRifle"}) do
    local n=nodesBySlot[slot]
    assert(n.top and not n.side and n.x+n.width<=w.diagram.width*0.45,
        "laser and light stay above the front barrel, never at the stock")
end
assert(nodesBySlot.Bipod.anchorX < nodesBySlot.Foregrip.anchorX
    and nodesBySlot.Foregrip.anchorX < nodesBySlot.Scope.anchorX,
    "top/bottom attachment anchors are horizontally reversed with the firearm")
assert(nodesBySlot.Scope.top
    and not nodesBySlot.Foregrip.top and not nodesBySlot.Bipod.top,
    "optics stay above while grip and bipod stay below")
for slot,node in pairs(nodesBySlot) do
    if node.side=="left" then
        assert(node.edgeX < node.elbowX and node.elbowX < node.anchorX,
            "left-side connector is reflected with its card: "..slot)
    elseif node.side=="right" then
        assert(node.anchorX < node.elbowX and node.elbowX < node.edgeX,
            "right-side connector is reflected with its card: "..slot)
    end
end
local emitted={}
for index,card in ipairs(w:diagramCards()) do
    local n=assert(geometry.nodes[index], "all eight main roles visible: "..card.slot)
    if card.slot=="Foregrip" or card.slot=="Bipod" then assert(not n.top) end
    emitted[#emitted+1]=string.format('{"slot":"%s","x":%d,"y":%d,"width":%d,"height":%d,"anchorX":%d,"anchorY":%d,"elbowY":%d,"top":%s}',
        card.slot,n.x,n.y,n.width,n.height,n.anchorX,n.anchorY,n.elbowY or n.anchorY,tostring(n.top==true))
end
local rifle={getModID=function() return "GaelGunStore_B42" end,isTwoHandWeapon=function() return true end}
local square={getWidth=function() return 32 end,getHeight=function() return 32 end}
local quad=assert(w.diagram:weaponQuad(rifle,square,geometry))
assert(quad[2].x>quad[4].x and quad[2].y==quad[4].y,
    "known diagonal rifle axis becomes horizontal without stretching")
assert(not w.diagram:weaponQuad(gun,square,geometry), "unknown artwork keeps original aspect")
local quadText={}
for _,point in ipairs(quad) do quadText[#quadText+1]=string.format('{"x":%.1f,"y":%.1f}',point.x,point.y) end
local g=geometry.gun
GMAWTestGeometryJSON=string.format('{"width":%d,"height":%d,"gun":{"x":%d,"y":%d,"width":%d,"height":%d},"nodes":[%s],"textureQuad":[%s]}',
    w.diagram.width,w.diagram.height,g.x,g.y,g.width,g.height,table.concat(emitted,','),table.concat(quadText,','))
-- Reproduce the user's seven-node Emre/GoM screenshot, including both muzzle slots.
local emreScene={slots={},bySlot={}}
for _,slot in ipairs({"Scope","Canon","Suppressor","Bipod","Foregrip","LaserRifle","LightRifle"}) do
    local card={slot=slot}
    emreScene.slots[#emreScene.slots+1]=card;emreScene.bySlot[slot]=card
end
w.view=emreScene
local emreLayout=checkDiagram(w)
local emreNodes={}
for i,card in ipairs(w:diagramCards()) do emreNodes[card.slot]=emreLayout.nodes[i] end
assert(emreNodes.Scope.top and emreNodes.LaserRifle.top and emreNodes.LightRifle.top
    and emreNodes.LightRifle.x+emreNodes.LightRifle.width<emreNodes.Scope.x,
    "front accessories stay above the barrel, separate from the central optics")
assert(emreNodes.Canon.side=="left" and emreNodes.Suppressor.side=="left",
    "muzzle cards retain the left edge")
assert(not emreNodes.Foregrip.top and not emreNodes.Bipod.top
    and not emreNodes.Foregrip.side and not emreNodes.Bipod.side,
    "only physically lower-mounted grip and bipod remain underneath")
local svd={slots={},bySlot={}}
for _,slot in ipairs({"Barrel_Shroud","Canon","Clip","Grip","Handguard","L_Scope","Laser","Light","Misc","Mount","Scope","Sling","Stock"}) do
    local card={slot=slot};svd.slots[#svd.slots+1]=card;svd.bySlot[slot]=card
end
w.view=svd
assert(#w:diagramCards()==12, "all twelve actual SVD slots remain; Mount merges into Scope")
local svdLayout=checkDiagram(w)
local svdNodes={}
for index,card in ipairs(w:diagramCards()) do
    local n=svdLayout.nodes[index]
    local cx=math.floor(n.x+n.width/2)
    local points=n.side and {{n.edgeX,n.edgeY},{n.elbowX,n.edgeY},{n.elbowX,n.anchorY},{n.anchorX,n.anchorY}}
        or {{cx,n.top and n.y+n.height or n.y},{cx,n.elbowY},{n.anchorX,n.elbowY},{n.anchorX,n.anchorY}}
    local pointText={}
    for _,point in ipairs(points) do pointText[#pointText+1]=string.format('[%d,%d]',point[1],point[2]) end
    svdNodes[#svdNodes+1]=string.format('{"slot":"%s","x":%d,"y":%d,"width":%d,"height":%d,"anchorX":%d,"anchorY":%d,"top":%s,"points":[%s]}',
        card.slot,n.x,n.y,n.width,n.height,n.anchorX,n.anchorY,tostring(n.top==true),table.concat(pointText,','))
end
local svdGun=svdLayout.gun
local svdQuad=w.diagram:weaponQuad(rifle,square,svdLayout)
local svdQuadText={}
for _,point in ipairs(svdQuad) do svdQuadText[#svdQuadText+1]=string.format('{"x":%.1f,"y":%.1f}',point.x,point.y) end
GMAWTestGeometryJSON=string.format('{"width":%d,"height":%d,"gun":{"x":%d,"y":%d,"width":%d,"height":%d},"nodes":[%s],"textureQuad":[%s]}',
    w.diagram.width,w.diagram.height,svdGun.x,svdGun.y,svdGun.width,svdGun.height,table.concat(svdNodes,','),table.concat(svdQuadText,','))
local sides=0
for _,node in pairs(svdLayout.nodes) do if node.side then sides=sides+1 end end
assert(sides==4, "GGS keeps muzzle, stock, sling and misc at the edges")
for index,card in ipairs(w:diagramCards()) do
    local node=svdLayout.nodes[index]
    if card.slot=="Laser" or card.slot=="Light" or card.slot=="Handguard"
        or card.slot=="Barrel_Shroud" then
        assert(not node.side and node.x+node.width<=w.diagram.width*0.45,
            "dense GGS front accessories remain in the front region: "..card.slot)
        assert(node.top==(card.slot=="Laser" or card.slot=="Light"),
            "front electronics above, barrel furniture below")
    end
end
for _,card in ipairs(svd.slots) do
    w.activeSlot=card.slot
    assert(w.diagram:cardLayout()==svdLayout,"SVD selection never changes geometry: "..card.slot)
end
-- The user's vz.58 plus denser provider sets: resizing must never send
-- front accessories to the stock side or create overlapping click targets.
local vz58={slots={},bySlot={}}
for _,slot in ipairs({"Canon","Light","Handguard","Barrel_Shroud","L_Scope",
    "Scope","Stock","Laser","Sling","Grip"}) do
    local card={slot=slot};vz58.slots[#vz58.slots+1]=card;vz58.bySlot[slot]=card
end
local oldWidth,oldHeight=w.diagram.width,w.diagram.height
for _,view in ipairs({vz58,svd,emreScene,many}) do
    w.view=view
    for _,size in ipairs({{300,375},{450,305},{624,375},{800,375}}) do
        w.diagram.width,w.diagram.height=size[1],size[2]
        local layout=checkDiagram(w)
        for i,card in ipairs(w:diagramCards()) do
            if card.slot=="Laser" or card.slot=="LaserRifle"
                or card.slot=="Light" or card.slot=="LightRifle"
                or card.slot=="Handguard" or card.slot=="Barrel_Shroud"
                or card.slot=="Bipod" then
                local n=layout.nodes[i]
                assert(not n.side and n.x+n.width<=size[1]*0.45,
                    "front cards wrap within their region on resize: "..card.slot)
            end
        end
    end
end
w.diagram.width,w.diagram.height=oldWidth,oldHeight
w.view=svd
w.activeSlot="Mount"
assert(w:diagramActiveSlot()=="Scope", "mount selection highlights existing scope group")
w.activeSlot="RailUp"
assert(w:diagramActiveSlot()=="Scope", "upper rail selection highlights existing scope group")
local railOnly={slots={},bySlot={}}
for _,slot in ipairs({"RailUp","RailDown","RailLeft","RailRight","CanonMount","Sling"}) do
    local card={slot=slot};railOnly.slots[#railOnly.slots+1]=card;railOnly.bySlot[slot]=card
end
w.view=railOnly
assert(#w:diagramCards()==1 and w:diagramCards()[1].slot=="Sling", "only functional attachments remain in central diagram")
w.view = originalView; w.activeSlot="Scope"
assert(#w.parts.items==2 and w.parts.items[1].item.item==scope and w.parts.items[2].item.dim)
w:choosePart(w.parts.items[2].item)
assert(#w.plan==0, "missing choice must not be queued")
w:choosePart(w.parts.items[1].item)
assert(w.view.bySlot.Scope.queued==scope and w.view.bySlot.Scope.installed==nil and #w.cart.items==1)
assert(w.activeSlot=="Scope" and w.applyButton.enabled)
w.pending=true; w:selectSlot(w.view.bySlot.RailUp); w:clear()
assert(w.activeSlot=="Scope" and #w.plan==1, "pending state cannot be changed")
w.pending=false
w.weapons:doDrawItem(0,w.weapons.items[1]); w.slots:doDrawItem(0,w.slots.items[2]); w.diagram:prerender()
w.parts:doDrawItem(0,w.parts.items[1]); w.parts:doDrawItem(66,w.parts.items[2]); w.cart:doDrawItem(0,w.cart.items[1]); w:prerender()
local hasMissingToolBorder=false
for _,draw in ipairs(w.draws) do if draw.border and draw.r>0.9 and draw.g<0.3 then hasMissingToolBorder=true end end
assert(hasMissingToolBorder, "missing or broken wrench uses a red disabled border")
local toolLabels, toolIcons = {}, {}
for _,draw in ipairs(w.draws) do
    if draw.text then toolLabels[draw.text] = true end
    if draw.texture then toolIcons[draw.texture] = draw end
end
assert(toolLabels.ToolStatus and toolLabels.ToolScrewdriver and toolLabels.ToolWrench
    and toolLabels.ToolReady and toolLabels.ToolMissing, "tools have names and explicit availability")
assert(toolIcons["screwdriver-icon"].height >= 40, "tool icon is enlarged")
assert(w.toolY + w.toolBoxSize < w.cartLabelY and w.statusY < w.toolLabelY,
    "tool cards fit between status and cart heading")
local textures={}
for _,list in ipairs({w.weapons,w.slots,w.mounts,w.parts,w.cart}) do
    for _,draw in ipairs(list.draws) do if draw.texture then textures[draw.texture]=draw end end
end
assert(textures["gun-icon"] and textures["scope-icon"], "item texture must actually be drawn")
local diagramGun = false
for _,draw in ipairs(w.diagram.draws) do if draw.texture == "gun-icon" then diagramGun = true end end
assert(diagramGun, "selected weapon is shown in the center diagram")
assert(textures["missing-icon"].alpha<1 and textures["missing-icon"].r<1, "missing icon is grey")
w.parts.draws={}; w.parts:setYScroll(-20)
w.parts:doDrawItem(0,w.parts.items[1])
assert(#w.parts.draws>0, "partly scrolled part row remains visible")
for _,draw in ipairs(w.parts.draws) do
    assert(draw.y + w.parts:getYScroll() >= 0,
        "part-row drawing must not escape above the list viewport")
end
w.parts:setYScroll(0)
w.weapons.mouseOver=true; w.weapons.mouseY=0; w.weapons:updateTooltip()
assert(w.weapons.items[1].item.item==gun, "weapon row holds selected gun")
w.searchEntry:setText("does not exist")
assert(#w.weapons.items==0 and #w.slots.items==0 and w.target==nil, "search hides unmatched weapons and clears stale preview")
w.searchEntry:setText("gun")
assert(#w.weapons.items==1 and w.target.item==gun, "search restores the supported weapon")
assert(w.weapons.tooltipUI, "weapon hover creates tooltip")
assert(w.weapons.tooltipUI.item==gun and w.weapons.tooltipUI.followMouse and w.weapons.tooltipUI.layout,
    "weapon hover uses the workbench tooltip with vanilla inventory styling")
w.slots.mouseOver=true; w.slots.mouseY=0; w.slots:updateTooltip()
assert(w.slots.tooltipUI==nil, "empty slot does not create an item tooltip")
w.parts.mouseOver=true; w.parts.mouseY=0; w.parts:updateTooltip()
assert(w.parts.tooltipUI and w.parts.tooltipUI.item==scope and w.parts.tooltipUI.layout,
    "attachment hover uses the workbench tooltip with vanilla inventory styling")
local labels={}
local tooltip={padLeft=5,padTop=5,padBottom=5,
    beginLayout=function()
        return {addItem=function()
            return {setLabel=function(_, text) labels[#labels+1]=text end}
        end,render=function() return 20 end}
    end,endLayout=function() end,setHeight=function(_, height) assert(height==25) end}
w.parts.tooltipUI:layout(tooltip)
assert(table.concat(labels, "\n"):find("TooltipDamage") and table.concat(labels, "\n"):find("TooltipMaxRange"),
    "custom attachment tooltip includes provided stats")
assert(table.concat(labels, "\n"):find("Aiming Time reduced by 5%%") and table.concat(labels, "\n"):find("Critical and Hit Chance increased by 15%%"),
    "custom attachment tooltip preserves authoritative GoM effects")
assert(not table.concat(labels, "\n"):find("Needs Screwdriver"), "custom attachment tooltip omits repeated tool instructions")
assert(not table.concat(labels, "\n"):find("M16A1"), "custom attachment tooltip never lists compatible weapons")
w.parts.mouseOver=false; w.parts:updateTooltip()
assert(not w.parts.tooltipUI.visible, "item tooltip hides after leaving its row")
w.cart.draws={}; w.cart:setYScroll(-100)
w.cart:doDrawItem(0,w.cart.items[1])
assert(#w.cart.draws==0, "offscreen cart row is clipped instead of drawing above its list")
w.cart:setYScroll(0)
w:clear(); assert(#w.plan==0 and not w.applyButton.enabled)
local A=require "GMAW/Actions"
local oldRemove=A.remove
local removed={}
A.remove=function(p,target,expected,slot)
    assert(p==player and target.item==gun)
    removed[#removed+1]=slot; return true
end
local card=w.view.bySlot.Scope
card.installed=scope
local rowIndex
for i,row in ipairs(w.slots.items) do if row.item==card then rowIndex=i end end
w.slots:onMouseDown(w.slots.width-38,(rowIndex-1)*w.slots.itemheight+15)
assert(#removed==1 and removed[1]=="Scope" and w.pending, "minus starts removal")
w.slots.doubleCallback(w,card)
assert(#removed==1, "pending prevents duplicate removal")
w.pending=false
w.slots.doubleCallback(w,card)
assert(#removed==2, "double click installed card removes")
A.active[player]={sentinel=true}
w:close(); assert(not GMAWWindows[0] and A.active[player].sentinel, "close never touches active work")
A.active[player]=nil;A.remove=oldRemove
-- The inventory callback and window lifecycle must remain reusable in one session.
local oldSpecificPlayer = getSpecificPlayer
getSpecificPlayer = function() return player end
local menu = { addOption = function(_, label, target, callback, selected)
    assert(target == player and selected == gun)
    callback(target, selected)
end }
for attempt = 1, 3 do
    gmawInventoryMenu(0, menu, {{items={gun}}})
    local reopened = assert(GMAWWindows[0], "menu can reopen after closing")
    reopened:close()
    assert(not GMAWWindows[0])
end
gmawInventoryMenu(0, menu, {{items={gun}}})
local previous = GMAWWindows[0]
gmawInventoryMenu(0, menu, {{items={gun}}})
local current = assert(GMAWWindows[0])
assert(current ~= previous, "opening an already open workbench replaces its window")
local oldScan = current.scan
scan = {entries={{item=gun,kind="Furniture",key="nearby"}},byType={}}
for frame = 1, 30 do current:update() end
assert(current.scan == oldScan, "periodic updates currently refresh tools only")
current:reload()
assert(current.scan == scan and current.target.kind == "Furniture",
    "refresh picks up a firearm moved into nearby storage")
assert(not current.screwdriver, "refresh removes a tool that is no longer available")
current:selectSlot(current.view.bySlot.Scope)
for _, row in ipairs(current.parts.items) do
    assert(row.item.dim, "refresh marks parts removed from nearby storage as unavailable")
end
current:close()
local savedTextManager = getTextManager
getTextManager = function()
    local manager = savedTextManager()
    manager.getFontHeight = function() return 22 end
    return manager
end
W.open(player,gun)
local large = GMAWWindows[0]
assert(large.toolBoxSize >= 56 and large.parts.height > 0 and large.slots.height > 0,
    "large-font tool cards retain positive list space on a smaller screen")
assert(large.toolY + large.toolBoxSize < large.cartLabelY
    and large.toolLabelY + 22 < large.toolY, "large-font tool labels do not overlap")
large.view=many
checkDiagram(large)
for _,slot in ipairs({"Scope","LightRifle"}) do
    large.activeSlot=slot
    local chosen
    for index,card in ipairs(large:diagramCards()) do if card.slot==slot then chosen=index end end
    assert(large.diagram:cardRect(chosen), "compact diagram promotes selected "..slot.." height="..large.diagram.height)
end
large.diagram.draws={}; large.diagram:prerender()
for _,draw in ipairs(large.diagram.draws) do
    assert(draw.y >= 0 and draw.y + (draw.height or 22) <= large.diagram.height,
        "large-font diagram rendering stays inside its panel")
end
-- Resizing and pane changes operate on existing controls, preserving work.
local Preferences = require "GMAW/UI/LayoutPreferences"
local originalSave, originalLoad = Preferences.save, Preferences.load
local savedLayout, saves = nil, 0
Preferences.save = function(_, prefs)
    savedLayout = {}
    for key,value in pairs(prefs) do savedLayout[key] = value end
    saves = saves + 1
end
getCore=function() return {getScreenWidth=function() return 1920 end,getScreenHeight=function() return 1080 end} end
getTextManager = savedTextManager
large:resetLayout()
assert(large.resizable and not large.layoutPrefs.weaponsCollapsed and large.weapons.visible,
    "default/reset layout enables resizing and expands the weapon list")
assert(large.resizeWidget.resizeFunction==W.resizeLayout and large.resizeWidget2.resizeFunction==W.resizeLayout
    and large.weaponToggle.target==large and large.weaponToggle.onclick==W.toggleWeapons
    and large.resetLayoutButton.onclick==W.resetLayout, "native resize grips and buttons are wired to layout actions")
local originalSlots, originalSearch, originalCart = large.slots, large.searchEntry, large.cart
large.activeSlot="Scope"; large.slots.selected=2; large.slots:setYScroll(-74)
large.searchEntry.text="saved filter"
local previousMiddle = large.middleWidth
large:toggleWeapons()
assert(not large.weapons.visible and not large.searchEntry.visible and large.weaponToggle.visible ~= false,
    "collapsed weapon list retains a reopen control")
assert(large.middleWidth > previousMiddle and savedLayout.weaponsCollapsed,
    "collapsing reclaims width and saves the user choice")
large:toggleWeapons()
large:resizeLayout(720,600)
large.layoutPrefs.middleRatio=0.3; large:layoutChildren()
assert(large.compactCenter and not large.diagram.visible and large.slots.y==66,
    "unreadable nodes are hidden and the original lower slot list fills the center")
assert(large.slots.y+large.slots.height<=large.diagramDivider.y,
    "compact mode reserves divider space outside the scrolling slot viewport")
large.layoutPrefs.leftRatio=0.4; large.layoutPrefs.middleRatio=0.8; large:layoutChildren()
assert(large.weapons.width>=160 and large.slots.width>=200 and large.parts.width>=180,
    "extreme saved ratios retain usable columns at the minimum window size")
large.layoutPrefs.leftRatio=0.23; large.layoutPrefs.middleRatio=0.3; large:layoutChildren()
for i=1,5 do large:layoutChildren(); assert(large.compactCenter,"unchanged compact geometry never oscillates") end
assert(large.slots==originalSlots and large.searchEntry==originalSearch and large.cart==originalCart
    and large.activeSlot=="Scope" and large.slots.selected==2 and large.slots:getYScroll()==-74
    and large.searchEntry.text=="saved filter", "layout changes preserve controls, selection, scroll and search")
large.layoutPrefs.middleRatio=0.75
large:resizeLayout(1500,950)
assert(not large.compactCenter and large.diagram.visible and large.slots.y>large.diagram.y,
    "spacious layout restores the diagram without replacing the slot list")
local divider=large.leftDivider
local oldRatio=large.layoutPrefs.leftRatio
divider:onMouseDown(4,10); divider.mouseX=80; divider:onMouseMoveOutside(76,0)
assert(divider.capture and large.layoutPrefs.leftRatio>oldRatio,
    "divider captures a drag and changes the panel width outside its grip")
divider:onMouseUpOutside(80,10)
assert(not divider.capture and savedLayout.leftRatio==large.layoutPrefs.leftRatio,
    "releasing outside saves the panel split and releases capture")
local middle=large.middleDivider
local oldMiddle=large.layoutPrefs.middleRatio
middle:onMouseDown(4,10); middle.mouseX=-60; middle:onMouseMove(-64,0); middle:onMouseUp(0,0)
assert(large.layoutPrefs.middleRatio<oldMiddle, "middle divider adjusts central and options widths")
local horizontal=large.diagramDivider
local oldDiagram=large.layoutPrefs.diagramRatio
horizontal:onMouseDown(10,4); horizontal.mouseY=-40; horizontal:onMouseMove(0,-44); horizontal:onMouseUp(0,0)
assert(large.layoutPrefs.diagramRatio<oldDiagram, "horizontal divider changes diagram/list allocation")
large:toggleWeapons()
large:close()
Preferences.load=function(_, sw, sh) return Preferences.sanitize(savedLayout,sw,sh) end
local nativeCreateChildren=ISCollapsableWindow.createChildren
local titlebarClose={x=1,y=1}
ISCollapsableWindow.createChildren=function(window)
    nativeCreateChildren(window)
    window.closeButton=titlebarClose
end
W.open(player,gun)
ISCollapsableWindow.createChildren=nativeCreateChildren
local restored=GMAWWindows[0]
assert(restored.closeButton==titlebarClose and restored.footerCloseButton~=titlebarClose
    and titlebarClose.x==1 and titlebarClose.y==1,
    "footer layout preserves the native titlebar close button and its position")
assert(restored.layoutPrefs.weaponsCollapsed and not restored.weapons.visible
    and restored.width==savedLayout.width and restored.height==savedLayout.height,
    "next opening restores the saved local layout and collapse choice")
restored:setX(80); restored:setY(60)
for frame=1,30 do restored:update() end
assert(savedLayout.x==80 and savedLayout.y==60, "moving an open window saves its position after a quiet interval")
restored:resetLayout()
assert(restored.weapons.visible and restored.layoutPrefs.leftRatio==0.23,
    "reset restores default panel proportions and expanded weapons")
restored:close()
Preferences.save, Preferences.load = originalSave, originalLoad
getCore=originalGetCore
getTextManager = savedTextManager
getSpecificPlayer = oldSpecificPlayer
M.supported,M.canOpen,M.candidates,M.toolKey,S.scan=saved.supported,saved.canOpen,saved.candidates,saved.toolKey,saved.scan
