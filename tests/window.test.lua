local W = require "GMAW/Window"
local M, S = require "GMAW/Model", require "GMAW/Sources"
local saved = {supported=M.supported,candidates=M.candidates,scan=S.scan,toolKey=M.toolKey}
local gun=item("gun",900); gun.getName=function() return "Gun" end; gun.getTex=function() return "gun-icon" end
gun.getAllWeaponParts=function() return javaList({}) end
local function part(name,id,slot)
    local p=item(name,id,slot); p.getName=function() return name end; p.getTex=function() return name.."-icon" end; return p
end
local rail,scope,missing=part("rail",1,"RailUp"),part("scope",2,"Scope"),part("missing",3,"Scope")
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
W.open(player,gun)
local w=assert(GMAWWindows[0])
assert(w.weapons.width>0 and w.slots.width>0 and w.mounts.width>0 and w.parts.width>0)
assert(w.screwdriver and w.screwdriver.item==screwdriver and w.wrench==nil,
    "working nearby screwdriver is enabled; broken nearby wrench is disabled")
assert(w.weapons.x+w.weapons.width<w.slots.x and w.slots.x+w.slots.width<w.mounts.x)
assert(w.mounts.width <= w.optionsWidth / 2 + 1 and w.parts.width <= w.optionsWidth / 2 + 1,
    "right panel is split into two equal columns")
assert(#w.slots.items==2 and #w.mounts.items==1 and w.mounts.items[1].item.item==rail)
w:selectSlot(w.view.bySlot.Scope)
assert(#w.parts.items==2 and w.parts.items[1].item.item==scope and w.parts.items[2].item.dim)
w:choosePart(w.parts.items[2].item)
assert(#w.plan==0, "missing choice must not be queued")
w:choosePart(w.parts.items[1].item)
assert(w.view.bySlot.Scope.queued==scope and w.view.bySlot.Scope.installed==nil and #w.cart.items==1)
assert(w.activeSlot=="Scope" and w.applyButton.enabled)
w.pending=true; w:selectSlot(w.view.bySlot.RailUp); w:clear()
assert(w.activeSlot=="Scope" and #w.plan==1, "pending state cannot be changed")
w.pending=false
w.weapons:doDrawItem(0,w.weapons.items[1]); w.slots:doDrawItem(0,w.slots.items[2])
w.parts:doDrawItem(0,w.parts.items[1]); w.parts:doDrawItem(66,w.parts.items[2]); w.cart:doDrawItem(0,w.cart.items[1]); w:prerender()
local hasMissingToolBorder=false
for _,draw in ipairs(w.draws) do if draw.border and draw.r>0.9 and draw.g<0.3 then hasMissingToolBorder=true end end
assert(hasMissingToolBorder, "missing or broken wrench uses a red disabled border")
for _,draw in ipairs(w.draws) do assert(draw.text ~= "ToolStatus" and draw.text ~= "ToolScrewdriver" and draw.text ~= "ToolWrench") end
local textures={}
for _,list in ipairs({w.weapons,w.slots,w.mounts,w.parts,w.cart}) do
    for _,draw in ipairs(list.draws) do if draw.texture then textures[draw.texture]=draw end end
end
assert(textures["gun-icon"] and textures["scope-icon"], "item texture must actually be drawn")
assert(textures["missing-icon"].alpha<1 and textures["missing-icon"].r<1, "missing icon is grey")
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
w.slots:onMouseDown(w.slots.width-38,(rowIndex-1)*124+15)
assert(#removed==1 and removed[1]=="Scope" and w.pending, "minus starts removal")
w.slots.doubleCallback(w,card)
assert(#removed==1, "pending prevents duplicate removal")
w.pending=false
w.slots.doubleCallback(w,card)
assert(#removed==2, "double click installed card removes")
A.active[player]={sentinel=true}
w:close(); assert(not GMAWWindows[0] and A.active[player].sentinel, "close never touches active work")
A.active[player]=nil;A.remove=oldRemove
M.supported,M.candidates,M.toolKey,S.scan=saved.supported,saved.candidates,saved.toolKey,saved.scan
