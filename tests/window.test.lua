local W = require "GMAW/Window"
local M, S = require "GMAW/Model", require "GMAW/Sources"
local saved = {supported=M.supported,candidates=M.candidates,scan=S.scan,toolKey=M.toolKey}
local gun=item("gun",900); gun.getName=function() return "Gun" end; gun.getTex=function() return "gun-icon" end
gun.getAllWeaponParts=function() return javaList({}) end
local function part(name,id,slot)
    local p=item(name,id,slot); p.getName=function() return name end; p.getTex=function() return name.."-icon" end; return p
end
local rail,scope,missing=part("rail",1,"RailUp"),part("scope",2,"Scope"),part("missing",3,"Scope")
scope.getPartType=function() return "Scope" end
scope.getFullType=function() return "MarzGuns.OKP3_Sight" end
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
M.supported=function() return true end; M.candidates=function() return catalog end
M.toolKey=function() return "Tools" end; S.scan=function() return scan end
local player={getPlayerNum=function() return 0 end,getInventory=function() return inventory({}) end}
local originalGetCore=getCore
getCore=function() return {getScreenWidth=function() return 1920 end,getScreenHeight=function() return 1080 end} end
W.open(player,gun)
getCore=originalGetCore
local w=assert(GMAWWindows[0])
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
assert(w.diagram.height == 254 and w.slots.height == 3 * w.slots.itemheight,
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
assert(#w:diagramCards() == 1 and w:diagramCards()[1].slot == "Scope",
    "narrow diagrams exclude rails while keeping real attachment slots")
w.diagram.width = fullWidth
local originalView = w.view
local many = {slots={},bySlot={}}
for _,slot in ipairs(M.slots) do
    local card = {slot=slot}
    many.slots[#many.slots + 1] = card; many.bySlot[slot] = card
end
w.view = many
assert(#w:diagramCards() == 6 and #w.view.slots == #M.slots,
    "diagram shortcuts never truncate the full supported slot model")
for _,card in ipairs(w:diagramCards()) do
    assert(card.slot ~= "CanonMount" and not card.slot:match("^Rail"), "diagram cards only show actual attachments")
end
local railOnly={slots={},bySlot={}}
for _,slot in ipairs({"RailUp","RailDown","RailLeft","RailRight","CanonMount","Sling"}) do
    local card={slot=slot};railOnly.slots[#railOnly.slots+1]=card;railOnly.bySlot[slot]=card
end
w.view=railOnly
assert(#w:diagramCards()==1 and w:diagramCards()[1].slot=="Sling", "fallback fills space with an attachment, never a rail or mount")
w.view = originalView
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
large:close()
getTextManager = savedTextManager
getSpecificPlayer = oldSpecificPlayer
M.supported,M.candidates,M.toolKey,S.scan=saved.supported,saved.candidates,saved.toolKey,saved.scan
