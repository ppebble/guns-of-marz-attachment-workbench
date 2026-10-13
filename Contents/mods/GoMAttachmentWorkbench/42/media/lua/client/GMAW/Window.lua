require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISToolTipInv"
require "Vehicles/ISUI/ISUI3DScene"
local M = require "GMAW/Model"
local P = require "GMAW/Planner"
local S = require "GMAW/Sources"
local V = require "GMAW/Presentation"
local UIProfiles = require "GMAW/UI/ProfileRegistry"
local AttachmentAnchors = require "GMAW/UI/AttachmentAnchors"
local LayoutPreferences = require "GMAW/UI/LayoutPreferences"
require "GMAW/Actions"
-- Do not retain require()'s transient nil during PZ client-script loading.
local A = GMAWActions
local W = ISCollapsableWindow:derive("GMAWWindow")
local T = ISToolTipInv:derive("GMAWItemTooltip")
local D = ISPanel:derive("GMAWWeaponDiagram")
local Divider = ISPanel:derive("GMAWDivider")
GMAWWindows = GMAWWindows or {}
local function tr(key) return getText("IGUI_GMAW_" .. key) end

local function fit(text, width)
    local clipped = text
    while #clipped > 0 and getTextManager():MeasureStringX(UIFont.Small, clipped .. "...") > width do
        local i = #clipped
        while i > 1 and clipped:byte(i) >= 128 and clipped:byte(i) < 192 do i = i - 1 end
        clipped = clipped:sub(1, i - 1)
    end
    return clipped == text and text or clipped .. "..."
end

-- Generated inventory textures can retain a small original-icon size while
-- their current texture is much larger. Fit the dimensions actually rendered.
local function fittedTexture(panel, texture, x, y, width, height, alpha, r, g, b)
    if type(texture) ~= "string" and texture.getWidth and texture.getHeight
        and texture:getWidth() > 0 and texture:getHeight() > 0 then
        local scale = math.min(width / texture:getWidth(), height / texture:getHeight())
        local tw, th = texture:getWidth() * scale, texture:getHeight() * scale
        panel:drawTextureScaled(texture, x + (width-tw)/2, y + (height-th)/2, tw, th, alpha, r, g, b)
    else
        panel:drawTextureScaledAspect(texture, x, y, width, height, alpha, r, g, b)
    end
end

local function icon(list, item, x, y, size, dim)
    local texture = item and item:getTex()
    list:drawRect(x, y, size, size, 0.45, 0.08, 0.08, 0.08)
    if texture then
        local shade = dim and 0.4 or 1
        fittedTexture(list, texture, x + 3, y + 3, size - 6, size - 6,
            dim and 0.5 or 1, shade, shade, shade)
    else list:drawText("-", x + size / 2 - 3, y + size / 2 - 8, 0.5, 0.5, 0.5, 1, UIFont.Small) end
end

local function toolTexture(item, fallback)
    if item and item:getTex() then return item:getTex() end
    return getTexture and getTexture(fallback) or nil
end

local function frame(list, y, selected)
    local width = list.width - 16
    local top = list.clipTop and math.max(y + 2, -list:getYScroll()) or y + 2
    local height = y + list.itemheight - 3 - top
    if height > 0 then
        list:drawRect(2, top, width - 4, height, 0.8, 0.12, 0.12, 0.12)
        list:drawRectBorder(2, top, width - 4, height, 0.9,
            selected and 0.95 or 0.3, selected and 0.6 or 0.3, selected and 0.15 or 0.3)
    end
    return width
end

local function visible(list, y)
    local scroll = list:getYScroll() or 0
    return y + scroll + list.itemheight >= 0 and y + scroll < list.height
end

local function number(value)
    local text = string.format("%.2f", value)
    return text:gsub("%.?0+$", "")
end

local function stat(lines, item, method, key)
    if not item[method] then return end
    local value = item[method](item)
    if value and value ~= 0 then
        lines[#lines + 1] = tr(key) .. ": " .. (value > 0 and "+" or "") .. number(value)
    end
end

local function upstreamStats(lines, item)
    local owner = item.getModID and item:getModID()
    if owner ~= "GunsOfMarz" and owner ~= "MarzGuns" then return end
    local ok, table = pcall(require, "MarzWeapons/ItemTooltipsTable")
    local entry = ok and table and table.tooltipsPergun and table.tooltipsPergun[item:getFullType()]
    if type(entry) == "string" then entry = {entry} end
    if type(entry) ~= "table" then return end
    for _, line in ipairs(entry) do
        -- The workbench already displays its tool requirement separately. Keep
        -- the authoritative GoM stat effects, but never repeat install advice.
        if type(line) == "string" and not line:match("^Needs ") then lines[#lines + 1] = line end
    end
end

function T:layout(tooltip)
    local item, lines = self.item, {}
    if item.getPartType then lines[#lines + 1] = tr("TooltipSlot") .. ": " .. tr("Slot_" .. item:getPartType()) end
    upstreamStats(lines, item)
    stat(lines, item, "getWeightModifier", "TooltipWeight")
    stat(lines, item, "getMinRangeRanged", "TooltipMinRange")
    stat(lines, item, "getMaxRange", "TooltipMaxRange")
    stat(lines, item, "getMinSightRange", "TooltipMinSightRange")
    stat(lines, item, "getMaxSightRange", "TooltipMaxSightRange")
    stat(lines, item, "getDamage", "TooltipDamage")
    stat(lines, item, "getRecoilDelay", "TooltipRecoilDelay")
    stat(lines, item, "getReloadTime", "TooltipReloadTime")
    stat(lines, item, "getAimingTime", "TooltipAimingTime")
    stat(lines, item, "getHitChance", "TooltipHitChance")
    stat(lines, item, "getClipSize", "TooltipClipSize")
    stat(lines, item, "getLowLightBonus", "TooltipLowLight")
    if item.getMaxDamage then
        local min, max = item:getMinDamage(), item:getMaxDamage()
        if min ~= 0 or max ~= 0 then lines[#lines + 1] = tr("TooltipDamage") .. ": " .. number(min) .. "-" .. number(max) end
    end
    local layout = tooltip:beginLayout()
    layout:addItem():setLabel(item:getName(), 1, 1, 1, 1)
    for _, line in ipairs(lines) do layout:addItem():setLabel(line, 0.85, 0.85, 0.85, 1) end
    local endY = layout:render(tooltip.padLeft or 5, tooltip.padTop or 5, tooltip)
    tooltip:endLayout(layout); tooltip:setHeight(endY + (tooltip.padBottom or 5))
end

-- Retain the vanilla inventory tooltip frame, placement, and sizing while
-- intentionally rendering only workbench-relevant stats (never MountOn).
function T:render()
    if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then return end
    local mx, my = getMouseX() + 24, getMouseY() + 24
    self.tooltip:setX(mx); self.tooltip:setY(my); self.tooltip:setWidth(50); self.tooltip:setMeasureOnly(true)
    self:layout(self.tooltip); self.tooltip:setMeasureOnly(false)
    local core, width, height = getCore(), self.tooltip:getWidth(), self.tooltip:getHeight()
    self.tooltip:setX(math.max(0, math.min(mx, core:getScreenWidth() - width - 1)))
    self.tooltip:setY(math.max(0, math.min(my, core:getScreenHeight() - height - 1)))
    self:setX(self.tooltip:getX()); self:setY(self.tooltip:getY()); self:setWidth(width); self:setHeight(height)
    self:adjustPositionToAvoidOverlap({x=mx - 48, y=my - 48, width=48, height=48})
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:layout(self.tooltip)
end

local function updateItemTooltip(list)
    local row = list:isMouseOver() and not list:isMouseOverScrollBar()
        and list:rowAt(list:getMouseX(), list:getMouseY()) or -1
    local data = list.items[row] and list.items[row].item
    local item = data and data.item
    if not item then
        if list.tooltipUI then list.tooltipUI:setVisible(false); list.tooltipUI:removeFromUIManager() end
        return
    end
    local tooltip = list.tooltipUI
    if tooltip then
        tooltip:setItem(item); tooltip:setVisible(true); tooltip:addToUIManager(); tooltip:bringToTop()
    else
        tooltip = T:new(item)
        tooltip:initialise(); tooltip:addToUIManager(); tooltip:setVisible(true); tooltip:setOwner(list)
        tooltip:setCharacter(getSpecificPlayer(list.gmawWindow.player:getPlayerNum()))
        list.tooltipUI = tooltip
    end
    tooltip.followMouse = true
end

local function drawItem(list, y, row)
    if not visible(list, y) then return y + list.itemheight end
    local d = row.item
    local width = frame(list, y, row.index == list.selected)
    local shade = d.dim and 0.45 or 0.95
    local top = list.clipTop and -list:getYScroll() or -math.huge
    if y + 8 >= top then icon(list, d.item, 8, y + 8, 48, d.dim) end
    if y + 9 >= top then
        list:drawText(fit(row.text, width - 70), 64, y + 9, shade, shade, shade, 1, UIFont.Small)
    end
    local green = not d.dim and (d.current or (d.quantity and d.quantity > 0))
    if y + 32 >= top then
        list:drawText(fit(d.subtitle or "", width - 70), 64, y + 32,
            green and 0.4 or shade, green and 0.95 or shade, green and 0.3 or shade, 1, UIFont.Small)
    end
    return y + list.itemheight
end

local function drawSlot(list, y, row)
    if not visible(list, y) then return y + list.itemheight end
    local d = row.item
    local width = frame(list, y, row.index == list.selected)
    list:drawText(fit(tr("Slot_" .. d.slot), width - 52), 10, y + 8, 0.9, 0.9, 0.9, 1, UIFont.Small)
    -- Installed-part removal; the rest of the card selects compatible options.
    local arrowShade = d.installed and not list.target.pending and 0.9 or 0.35
    list:drawRectBorder(width - 34, y + 7, 24, 24, 1, arrowShade, arrowShade, arrowShade)
    list:drawText("-", width - 26, y + 9, arrowShade, arrowShade, arrowShade, 1, UIFont.Small)
    icon(list, d.installed, 10, y + 27, 27, false)
    list:drawText(fit(d.installed and d.installed:getName() or tr("Empty"), width - 58),
        44, y + 32, 0.95, 0.95, 0.95, 1, UIFont.Small)
    if d.queued then
        list:drawText(fit(tr(d.automatic and "AutoQueued" or "Queued") .. ": " .. d.queued:getName(), width - 20),
            10, y + 54, 0.95, 0.75, 0.3, 1, UIFont.Small)
    end
    return y + list.itemheight
end

-- Physical-role anchors are approximate; selection never changes geometry.
local diagramRoles = {
    Scope={0.43,true,1,0.36}, Stock={0.10,true,2,0.02},
    Canon={0.96,true,3,0.98}, Suppressor={0.96,true,3,0.98},
    LaserRifle={0.57,true,4,0.55}, Laser={0.57,true,4,0.55},
    Foregrip={0.64,false,5,0.43}, Grip={0.64,false,5,0.43},
    LightRifle={0.77,false,6,0.75}, Light={0.77,false,6,0.75},
    Bipod={0.87,false,7,0.98}, L_Scope={0.48,true,8,0.50},
    Barrel={0.84,true,9,0.86}, Underbarrel={0.69,false,10,0.75},
    Handguard={0.65,false,10,0.66}, Clip={0.43,false,11,0.28},
    Barrel_Shroud={0.82,true,12,0.82}, Shellholder={0.32,false,13,0.15},
    RecoilPad={0.05,true,14,0.01}, Sling={0.23,false,15,0.02},
    Hide_Beam={0.60,true,16,0.60}, Misc={0.35,false,17,0.12},
    Stool={0.72,false,18,0.82},
}
local prerequisiteTarget = {RailUp="Scope", Mount="Scope", RailDown="Foregrip",
    RailLeft="LaserRifle", RailRight="LightRifle", CanonMount="Canon"}
-- Card placement only; diagramRoles still supplies the existing leader anchors.
-- Coordinates are in the pre-reflection layout (front = right).
local cardPositions = {
    Laser={0.78,true}, LaserRifle={0.78,true},
    Light={0.92,true}, LightRifle={0.92,true},
    Barrel={0.85,true}, Hide_Beam={0.85,true},
    Handguard={0.70,false}, Barrel_Shroud={0.82,false},
    Bipod={0.94,false}, Underbarrel={0.64,false}, Stool={0.82,false},
    Foregrip={0.50,false}, Grip={0.50,false},
}
function W:diagramCards()
    local result={}
    for _,card in ipairs(self.view and self.view.slots or {}) do
        if not prerequisiteTarget[card.slot] then result[#result+1]=card end
    end
    return result
end
function W:diagramActiveSlot()
    return prerequisiteTarget[self.activeSlot] or self.activeSlot
end

function D:cardLayout()
    local font=getTextManager():getFontHeight(UIFont.Small)
    local cached=self.spatialLayout
    if cached and cached.view==self.window.view and cached.width==self.width
        and cached.height==self.height and cached.fontHeight==font then return cached end
    local cards=self.window:diagramCards()
    local upper,lower,left,right={},{},{},{}
    -- Distribute physical end/side parts along the outer edges. When a side
    -- fills up, keep the overflow visible in its original top/bottom lane.
    local sideRoles={Canon="right",Suppressor="right",Stock="left",Sling="left",
        RecoilPad="left",Shellholder="left",Misc="left"}
    local useSides=self.width>=450 and self.height>=255
    local sideCapacity=self.height>=350 and 4 or self.height>=305 and 3
        or self.height>=255 and 2 or 0
    local sideCandidates={left={},right={}}
    for index,card in ipairs(cards) do
        local role=diagramRoles[card.slot] or {0.4,false,20,0.2}
        local side=useSides and sideRoles[card.slot]
        local position=cardPositions[card.slot] or role
        local entry={index=index,role=role,position=position}
        if side then
            sideCandidates[side][#sideCandidates[side]+1]=entry
        else
            local group=position[2] and upper or lower
            group[#group+1]=entry
        end
    end
    for _,side in ipairs({"left","right"}) do
        local candidates=sideCandidates[side]
        table.sort(candidates,function(a,b)
            if a.role[3]==b.role[3] then return a.index<b.index end
            return a.role[3]<b.role[3]
        end)
        for i,entry in ipairs(candidates) do
            local target
            if i<=sideCapacity then target=side=="left" and left or right
            else target=entry.position[2] and upper or lower end
            target[#target+1]=entry
        end
    end
    local sideHeight=font*2+10
    local gunHeight=math.max(56,math.floor(self.height*(useSides and 0.39 or 0.25)),
        math.max(#left,#right)*(sideHeight+7)+8)
    local choice
    -- Reserve separate horizontal regions so dense front cards wrap locally
    -- instead of pushing the optics or crossing into the stock region.
    local split=math.floor(self.width*0.55)
    local function zone(entry) return entry.position[1]>0.60 and 2 or 1 end
    local function rowsFor(group,columns)
        local counts={0,0}
        for _,entry in ipairs(group) do local z=zone(entry);counts[z]=counts[z]+1 end
        return math.max(math.ceil(counts[1]/columns[1]),math.ceil(counts[2]/columns[2]))
    end
    -- Keep full labels and installed-part details whenever possible. A dense
    -- small viewport uses one-line nodes; the full details stay in the lists.
    for _,detail in ipairs({true,false}) do
        for _,desiredWidth in ipairs({112,104,92,80,68,54,42}) do
            local spans={split-10,self.width-split-10}
            local columns={math.max(1,math.floor((spans[1]+8)/(desiredWidth+8))),
                math.max(1,math.floor((spans[2]+8)/(desiredWidth+8)))}
            local cardWidth=math.min(116,
                math.floor((spans[1]-(columns[1]-1)*8)/columns[1]),
                math.floor((spans[2]-(columns[2]-1)*8)/columns[2]))
            local cardHeight=font*(detail and 2 or 1)+(detail and 10 or 6)
            local upperRows=rowsFor(upper,columns)
            local lowerRows=rowsFor(lower,columns)
            local needed=font+10+(upperRows+lowerRows)*(cardHeight+12)+gunHeight+12
            if needed<=self.height then
                choice={columns=columns,cardWidth=cardWidth,cardHeight=cardHeight,
                    upperRows=upperRows,lowerRows=lowerRows,detail=detail,gap=8}; break
            end
        end
        if choice then break end
    end
    -- Extreme font/viewport combinations still get every hit target. The
    -- normal window reserves enough diagram space for the provider slot sets.
    if not choice then
        local columns=math.max(1,#upper,#lower)
        choice={columns={columns,columns},cardWidth=math.max(1,math.floor((math.min(split-10,self.width-split-10)-(columns-1)*2)/columns)),
            cardHeight=font+6,upperRows=1,lowerRows=1,detail=false,gap=2}
    end
    local c=choice
    local used=font+10+(c.upperRows+c.lowerRows)*(c.cardHeight+12)+gunHeight+12
    local gunY=font+10+c.upperRows*(c.cardHeight+12)+math.max(0,math.floor((self.height-used)/2))
    local gunInset=useSides and math.floor(self.width*0.19) or 18
    local l={view=self.window.view,width=self.width,height=self.height,fontHeight=font,
        nodes={},details=c.detail,gun={x=gunInset,y=gunY,width=self.width-gunInset*2,height=gunHeight}}
    local function place(group,top,rows,region)
        table.sort(group,function(a,b)
            if a.position[1]==b.position[1] then return a.index<b.index end
            return a.position[1]<b.position[1]
        end)
        -- Put cards near their physical attachment points, not into the
        -- first N grid cells. Keep minimum separation and independent leaders.
        local lanes={}
        for row=1,math.max(1,rows) do lanes[row]={} end
        for i,entry in ipairs(group) do
            local lane=lanes[1+(i-1)%math.max(1,rows)]
            lane[#lane+1]=entry
        end
        for row,entries in ipairs(lanes) do
            local pitch=c.cardWidth+(c.gap or 8)
            local start=(region==1 and 6 or split+4)+c.cardWidth/2
            local finish=(region==1 and split-4 or self.width-6)-c.cardWidth/2
            local centers={}
            -- Balanced packing: share any unavoidable horizontal offset across
            -- neighboring cards instead of stretching the last leader alone.
            local blocks={}
            for i,entry in ipairs(entries) do
                local preferred=l.gun.x+l.gun.width*(0.08+entry.position[1]*0.84)
                blocks[#blocks+1]={first=i,last=i,total=preferred-(i-1)*pitch,count=1}
                while #blocks>=2 do
                    local right=blocks[#blocks]
                    local left=blocks[#blocks-1]
                    if left.total/left.count<=right.total/right.count then break end
                    left.last=right.last;left.total=left.total+right.total;left.count=left.count+right.count
                    blocks[#blocks]=nil
                end
            end
            for _,block in ipairs(blocks) do
                local offset=math.max(start,math.min(finish-(#entries-1)*pitch,block.total/block.count))
                for i=block.first,block.last do centers[i]=offset+(i-1)*pitch end
            end
            for i,entry in ipairs(entries) do
                local stagger=((i+row)%3)*2
                local y=top and gunY-10-row*(c.cardHeight+8)-stagger
                    or gunY+gunHeight+10+(row-1)*(c.cardHeight+8)+stagger
                local anchorX=math.floor(l.gun.x+l.gun.width*(0.08+entry.role[1]*0.84))
                l.nodes[entry.index]={x=math.floor(centers[i]-c.cardWidth/2),y=y,
                    width=c.cardWidth,height=c.cardHeight,top=top,
                    anchorX=anchorX,anchorY=top and gunY+2 or gunY+gunHeight-2,
                    elbowY=top and gunY-6-(i%2)*2 or gunY+gunHeight+6+(i%2)*2}
            end
        end
    end
    for region=1,2 do
        local top,bottom={},{}
        for _,entry in ipairs(upper) do if zone(entry)==region then top[#top+1]=entry end end
        for _,entry in ipairs(lower) do if zone(entry)==region then bottom[#bottom+1]=entry end end
        place(top,true,math.ceil(#top/c.columns[region]),region)
        place(bottom,false,math.ceil(#bottom/c.columns[region]),region)
    end
    local function placeSide(group,side)
        table.sort(group,function(a,b) return a.role[3]<b.role[3] end)
        local height=sideHeight
        local width=gunInset-12
        local gap=math.max(4,math.floor((gunHeight-#group*height)/(#group+1)))
        for index,entry in ipairs(group) do
            local rightSide=side=="right"
            local x=rightSide and self.width-width-6 or 6
            local y=gunY+index*gap+(index-1)*height
            local edgeX=rightSide and x or x+width
            local edgeY=y+math.floor(height/2)
            local anchorX=rightSide and l.gun.x+l.gun.width-3 or l.gun.x+3
            local anchorY=edgeY
            l.nodes[entry.index]={x=x,y=y,width=width,height=height,side=side,
                edgeX=edgeX,edgeY=edgeY,anchorX=anchorX,anchorY=anchorY,
                elbowX=math.floor((edgeX+anchorX)/2)}
        end
    end
    placeSide(left,"left");placeSide(right,"right")
    -- The native fixed-profile preview visibly points left in-game. Mirror
    -- only the UI layout to match its muzzle/stock ends, never the 3D model.
    -- Reflect every connector point as well as each card's hit rectangle so
    -- all leader lines, hit tests and selection remain attached to the card.
    for _,node in pairs(l.nodes) do
        node.x=self.width-node.x-node.width
        node.anchorX=self.width-node.anchorX
        if node.edgeX then node.edgeX=self.width-node.edgeX end
        if node.elbowX then node.elbowX=self.width-node.elbowX end
        if node.side=="left" then node.side="right"
        elseif node.side=="right" then node.side="left" end
    end
    self.spatialLayout=l
    return l
end
function D:cardRect(index,layout)
    local n=(layout or self:cardLayout()).nodes[index]
    if n then return n.x,n.y,n.width,n.height end
end
local function segment(panel,x1,y1,x2,y2,selected)
    -- Avoid artificial 1x1 "dots" from coincident endpoints. The leaders
    -- indicate approximate slot regions, not verified mesh attach points.
    if x1==x2 and y1==y2 then return end
    panel:drawRect(math.min(x1,x2),math.min(y1,y2),math.max(1,math.abs(x2-x1)),
        math.max(1,math.abs(y2-y1)),selected and 0.62 or 0.34,
        selected and 1 or 0.48,selected and 0.65 or 0.40,0.18)
end
-- Known square rifle icons point from lower-left to upper-right. Rotate the
-- original texture uniformly; never stretch its silhouette to fill the panel.
function D:weaponQuad(gun,texture,layout)
    local owner=gun.getModID and gun:getModID()
    if (owner~="GaelGunStore_B42" and owner~="GunsOfMarz" and owner~="MarzGuns")
        or not gun.isTwoHandWeapon or not gun:isTwoHandWeapon()
        or type(texture)=="string" or not texture.getWidth or not texture.getHeight
        or texture:getWidth()~=texture:getHeight() then return nil end
    if texture.getWidthOrig and texture.getHeightOrig
        and (texture:getWidthOrig()~=texture:getWidth() or texture:getHeightOrig()~=texture:getHeight()) then
        return nil -- generated thumbnails are not the known diagonal icon
    end
    local g=layout.gun
    local cx,cy=g.x+g.width/2,g.y+g.height/2
    local radius=g.width*0.42
    return {{x=cx,y=cy-radius},{x=cx+radius,y=cy},
        {x=cx,y=cy+radius},{x=cx-radius,y=cy}}
end
local function fixedPreviewInput() return true end
-- Lua exposes attachment offsets, but not the mesh bounds. Estimate framing
-- from those points with silhouette clearance; never edit the model script.
function D:modelDirection(script)
    local muzzle=script.getAttachmentById and script:getAttachmentById("muzzle")
    if not muzzle then return 1 end
    local front=muzzle:getOffset():y()
    for _,id in ipairs({"Stock","stock","RecoilPad","Grip","grip","magazine"}) do
        local rear=script:getAttachmentById(id)
        if rear then
            local distance=front-rear:getOffset():y()
            if math.abs(distance)>0.03 then return distance<0 and -1 or 1 end
        end
    end
    if script.getAttachmentCount then
        local minY,maxY
        for i=0,script:getAttachmentCount()-1 do
            local a=script:getAttachment(i)
            if a:getId()~="world" and a:getId()~="muzzle" then
                local y=a:getOffset():y()
                minY=math.min(minY or y,y); maxY=math.max(maxY or y,y)
            end
        end
        if minY and front<minY-0.03 then return -1 end
        if maxY and front>maxY+0.03 then return 1 end
    end
    return front<0 and -1 or 1
end
function D:modelUpSign(gun,script)
    local profile=UIProfiles.forWeapon(gun)
    local fullType=script.getFullType and script:getFullType()
    local name=fullType and fullType:match("^MarzGuns%.([^%.]+)$")
    return profile and profile.invertedUpModels and profile.invertedUpModels[name] and -1 or 1
end
function D:modelFrame(script,upSign)
    if not script.getAttachmentCount then return nil end
    local direction=self:modelDirection(script)
    local bounds
    for i=0,script:getAttachmentCount()-1 do
        local a=script:getAttachment(i)
        if a:getId()~="world" then
            local p=a:getOffset()
            local x,y,z=p:x(),p:y(),p:z()
            -- The fixed native Right camera (Y=90) and a model X=-90
            -- project the held-model Y axis horizontally and Z upright.
            x,z=y*direction,z*(upSign or 1)
            if x==x and z==z and math.abs(x)<10 and math.abs(z)<10 then
                if not bounds then bounds={left=x,right=x,bottom=z,top=z,count=0,hasStock=false} end
                bounds.left=math.min(bounds.left,x);bounds.right=math.max(bounds.right,x)
                bounds.bottom=math.min(bounds.bottom,z);bounds.top=math.max(bounds.top,z)
                if a:getId()=="Stock" or a:getId()=="stock" or a:getId()=="RecoilPad" then
                    bounds.hasStock=true
                end
                bounds.count=bounds.count+1
            end
        end
    end
    if not bounds or bounds.count<2 or bounds.right-bounds.left<0.05 then return nil end
    return bounds
end
-- Attachment offsets are NOT mesh vertices. In particular Emre AWP has only
-- muzzle (Y=.5781) and magazine (Y=.1035): the stock extends behind both.
-- Reserve conservative rear/up/down silhouette room; do not pretend that
-- mounting-point bounds are the full geometry of the weapon.
function D:modelEnvelope(b)
    local length=b.right-b.left
    local rear=math.max(b.hasStock and 0.14 or 0.27,
        length*(b.hasStock and 0.35 or 0.90))
    local front=math.max(0.07,length*0.14)
    local fullLength=length+rear+front
    local down=math.max(0.11,fullLength*0.24)
    local up=math.max(0.11,fullLength*0.18)
    return {left=b.left-rear,right=b.right+front,
        bottom=b.bottom-down,top=b.top+up}
end
function D:fitModelPreview(scene)
    local b=scene.frameBounds
    if not b or (scene.fitWidth==scene.width and scene.fitHeight==scene.height) then return end
    local e=self:modelEnvelope(b)
    local framedWidth=e.right-e.left
    local framedHeight=math.max(e.top-e.bottom,framedWidth*0.47)
    local pixelsPerUnit=scene.width/1366*math.exp(13*0.2)*160/1.82
    local scale=math.min(scene.width*0.86/(framedWidth*pixelsPerUnit),
        scene.height*0.86/(framedHeight*pixelsPerUnit))
    scale=math.max(0.05,math.min(8,scale))
    local j=scene.javaObject
    j:fromLua1("setZoom",13)
    j:fromLua1("getObjectScale","weapon"):set(scale,scale,scale)
    -- Native SceneObject transform is T * R * S. With View.Right (90 Y),
    -- screen X = world Z, so the horizontal centering offset is world Z,
    -- NOT world X. Old X translation could never center this camera.
    local tx,ty,tz=0,-(e.bottom+e.top)/2*scale,(e.left+e.right)/2*scale
    j:fromLua1("getObjectTranslation","weapon"):set(tx,ty,tz)
    -- Retain the ACTUAL fitted scene transform for provider-specific visual
    -- leader projection. This is read-only metadata; never alter the mesh.
    scene.anchorScale=scale
    scene.anchorTranslation={x=tx,y=ty,z=tz}
    scene.leaderCache=nil
    scene.fitWidth,scene.fitHeight=scene.width,scene.height
end
function D:clearModelPreview()
    if self.modelScene then
        pcall(function() self.modelScene.javaObject:fromLua1("removeModel","weapon") end)
        self.modelScene:setVisible(false)
        self:removeChild(self.modelScene)
        self.modelScene=nil
    end
    self.previewGun=nil
end
function D:updateModelPreview(gun,layout)
    if gun~=self.previewGun then
        self:clearModelPreview()
        self.previewGun=gun
        if gun and ISUI3DScene and gun.getStaticModel then
            local ok=pcall(function()
                local name=gun:getStaticModel()
                if not name or name=="" then return end
                local script=getScriptManager():getModelScript(name)
                if not script then return end
                local g=layout.gun
                local scene=ISUI3DScene:new(g.x,g.y,g.width,g.height)
                self.modelScene=scene
                scene:initialise();scene:instantiate();self:addChild(scene)
                scene.background=false
                scene.onMouseDown=fixedPreviewInput;scene.onMouseUp=fixedPreviewInput
                scene.onMouseMove=fixedPreviewInput;scene.onMouseMoveOutside=fixedPreviewInput
                scene.onMouseUpOutside=fixedPreviewInput;scene.onMouseWheel=fixedPreviewInput
                -- UI3DScene starts in View.Right. Switching to UserDefined
                -- triggers a native 350 ms quaternion camera animation.
                -- Setting Right again is a no-op: the gun appears instantly.
                scene:setView("Right")
                local j=scene.javaObject
                j:fromLua1("setDrawGrid",false)
                j:fromLua1("setDrawGridAxes",false)
                j:fromLua1("setDrawGridPlane",false)
                j:fromLua1("setMaxZoom",20)
                local longGun=gun:isTwoHandWeapon()
                j:fromLua1("setZoom",longGun and 13 or 17)
                j:fromLua2("createModel","weapon",script:getFullType())
                scene.previewScript=script
                j:fromLua2("setObjectAutoRotate","weapon",false)
                j:fromLua2("setModelUseWorldAttachment","weapon",false)
                j:fromLua2("setModelWeaponRotationHack","weapon",false)
                -- Held model: forward local Y becomes screen left, local Z
                -- stays up. For reversed-Y barrels, roll 180 around model Z
                -- before the X=-90 tip; do not roll the camera or view.
                local reverse=self:modelDirection(script)<0
                local upSign=self:modelUpSign(gun,script)
                scene.anchorUpSign=upSign
                -- A Y half-turn corrects authored negative-Z up without
                -- changing the forward Y axis or the left-facing muzzle.
                j:fromLua1("getObjectRotation","weapon"):set(-90,upSign<0 and 180 or 0,reverse and 180 or 0)
                j:fromLua1("getObjectTranslation","weapon"):set(0,0,0)
                local framed,bounds=pcall(self.modelFrame,self,script,upSign)
                scene.frameBounds=framed and bounds or nil
                self:fitModelPreview(scene)
            end)
            if not ok then self:clearModelPreview();self.previewGun=gun end
        end
    end
    local scene=self.modelScene
    if scene then
        local g=layout.gun
        if scene.x~=g.x then scene:setX(g.x) end
        if scene.y~=g.y then scene:setY(g.y) end
        if scene.width~=g.width then scene:setWidth(g.width) end
        if scene.height~=g.height then scene:setHeight(g.height) end
        self:fitModelPreview(scene)
    end
    return scene~=nil
end
function D:providerLeaderPoints(gun)
    local profile=UIProfiles.forWeapon(gun)
    if not profile then return {} end -- No verified geometry: cards only.
    local scene=self.modelScene
    if not scene or not scene.previewScript or not scene.anchorScale then return {} end
    local cached=scene.leaderCache
    if cached and cached.width==scene.width and cached.height==scene.height
        and cached.x==scene.x and cached.y==scene.y and cached.view==self.window.view
        and cached.profile==profile then return cached.points end
    local points={}
    local script=scene.previewScript
    local direction=self:modelDirection(script)
    local foundAttachment=false
    for index,card in ipairs(self.window:diagramCards()) do
        local valid,attachment=pcall(AttachmentAnchors.resolve,profile,script,card.slot)
        if valid and attachment then
            foundAttachment=true
            local projected,point=pcall(AttachmentAnchors.project,profile,scene,attachment,direction)
            if projected and point then
                points[index]={x=scene.x+point.x,y=scene.y+point.y,id=attachment.id}
            end
        end
    end
    -- An initially unready native projector can briefly return no usable
    -- points. Retry on a few subsequent frames before caching an empty map.
    scene.leaderAttempts=(scene.leaderAttempts or 0)+1
    local hasPoint=false
    for _ in pairs(points) do hasPoint=true; break end
    if hasPoint or not foundAttachment or scene.leaderAttempts>=3 then
        scene.leaderCache={profile=profile,width=scene.width,height=scene.height,
            x=scene.x,y=scene.y,view=self.window.view,points=points}
    end
    return points
end
function D:prerender()
    ISPanel.prerender(self)
    self:drawRect(0,0,self.width,self.height,0.85,0.055,0.065,0.075)
    local l=self:cardLayout()
    local gun=self.window.target and self.window.target.item
    local modelVisible=self:updateModelPreview(gun,l)
    local providerPoints=self:providerLeaderPoints(gun)
    if gun then
        self:drawText(fit(gun:getName(),self.width-16),8,3,0.95,0.95,0.95,1,UIFont.Small)
        local texture=not modelVisible and gun:getTex()
        if texture and not modelVisible then
            local quad=self:weaponQuad(gun,texture,l)
            if quad then
                self:setStencilRect(l.gun.x,l.gun.y,l.gun.width,l.gun.height)
                -- Unlike the scaled-texture APIs, this native quad API does
                -- not add the UI element's position to the supplied vertices.
                local ax, ay = self:getAbsoluteX(), self:getAbsoluteY()
                self:drawTextureAllPoint(texture,quad[1].x+ax,quad[1].y+ay,quad[2].x+ax,quad[2].y+ay,
                    quad[3].x+ax,quad[3].y+ay,quad[4].x+ax,quad[4].y+ay,1,1,1,1)
                self:clearStencilRect()
                self:repaintStencilRect(0,0,self.width,self.height)
            else fittedTexture(self,texture,l.gun.x,l.gun.y,l.gun.width,l.gun.height,1,1,1,1) end
        end
    end
    for index,card in ipairs(self.window:diagramCards()) do
        local n=l.nodes[index]
        if n then
            local x,y,width,height=n.x,n.y,n.width,n.height
            local selected=card.slot==self.window:diagramActiveSlot()
            local cx=math.floor(x+width/2)
            local point=providerPoints[index]
            if selected and point then
                if n.side then
                    local elbowX=math.floor((n.edgeX+point.x)/2)
                    segment(self,n.edgeX,n.edgeY,elbowX,n.edgeY,selected)
                    segment(self,elbowX,n.edgeY,elbowX,point.y,selected)
                    segment(self,elbowX,point.y,point.x,point.y,selected)
                else
                    segment(self,cx,n.top and y+height or y,cx,n.elbowY,selected)
                    segment(self,cx,n.elbowY,point.x,n.elbowY,selected)
                    segment(self,point.x,n.elbowY,point.x,point.y,selected)
                end
            end
            -- No endpoint square: model scripts often lack the exact position
            -- of this slot, so a prominent pin would imply false precision.
            self:drawRect(x,y,width,height,0.97,0.1,0.11,0.12)
            self:drawRectBorder(x,y,width,height,1,selected and 0.98 or 0.38,selected and 0.62 or 0.43,selected and 0.18 or 0.47)
            self:drawText(fit(tr("Slot_"..card.slot),width-8),x+4,y+3,0.9,0.9,0.9,1,UIFont.Small)
            if l.details then
            local shown=card.queued or card.installed
            local detailY=y+l.fontHeight+6
            if shown then
                local texture=shown:getTex()
                if texture then self:drawTextureScaledAspect(texture,x+4,detailY,18,l.fontHeight,1,1,1,1) end
                self:drawText(fit(shown:getName(),width-28),x+24,detailY,card.queued and 1 or 0.8,0.8,0.4,1,UIFont.Small)
            else self:drawText(fit(tr("Empty"),width-8),x+4,detailY,0.55,0.58,0.61,1,UIFont.Small) end
            end
        end
    end
end
function D:onMouseDown(x,y)
    local l=self:cardLayout()
    for index,card in ipairs(self.window:diagramCards()) do
        local n=l.nodes[index]
        if n and x>=n.x and x<n.x+n.width and y>=n.y and y<n.y+n.height then
            self.window:selectSlot(card);return true
        end
    end
    return false
end

function Divider:onMouseDown(x, y)
    self.dragging = true
    self.downX, self.downY = self.x + x, self.y + y
    local w = self.window
    self.startRatio = self.axis == "left" and w.leftWidth / (w.width - 40)
        or self.axis == "middle" and w.middleWidth / (w.width - w.middleX - 20) or w.layoutPrefs.diagramRatio
    self:setCapture(true)
    return true
end
function Divider:onMouseMove(dx, dy)
    if not self.dragging then return end
    local w, prefs = self.window, self.window.layoutPrefs
    if self.axis == "left" then
        prefs.leftRatio = self.startRatio + (self.x + self:getMouseX() - self.downX) / (w.width - 40)
    elseif self.axis == "middle" then
        prefs.middleRatio = self.startRatio + (self.x + self:getMouseX() - self.downX) / (w.width - w.middleX - 20)
    else
        prefs.diagramRatio = self.startRatio + (self.y + self:getMouseY() - self.downY) / w.panelHeight
    end
    w.layoutPrefs = LayoutPreferences.sanitize(prefs, getCore():getScreenWidth(), getCore():getScreenHeight())
    w:layoutChildren()
    w.layoutSaveFrames = 30
    return true
end
Divider.onMouseMoveOutside = Divider.onMouseMove
function Divider:onMouseUp(x, y)
    if not self.dragging then return end
    self.dragging = false
    self:setCapture(false)
    self.window:saveLayout()
    return true
end
Divider.onMouseUpOutside = Divider.onMouseUp
function Divider:prerender()
    local shade = self.dragging and 0.8 or 0.4
    if self.axis == "diagram" then
        self:drawRect(0, math.floor(self.height / 2), self.width, 2, 0.8, shade, shade, shade)
    else
        self:drawRect(math.floor(self.width / 2), 0, 2, self.height, 0.8, shade, shade, shade)
    end
end

local function bounds(control, x, y, width, height)
    control:setX(x); control:setY(y)
    control:setWidth(math.max(1, width)); control:setHeight(math.max(1, height))
end

-- Evaluate actual font-dependent node geometry, including dense slot sets.
-- Returning from the list requires extra room to avoid boundary flicker.
function W:diagramFits()
    local width, height = self.diagram.width, self.diagram.height
    local margin = self.compactCenter and 24 or 0
    -- Probe a smaller candidate while compact; requiring spare width AND
    -- height also stabilizes transitions caused by wrapping into another row.
    self.diagram.width, self.diagram.height = width - margin, height - margin
    local layout = self.diagram:cardLayout()
    self.diagram.width, self.diagram.height = width, height
    if layout.gun.width < 150 or layout.gun.height < 56 then return false end
    for _, node in pairs(layout.nodes) do
        if node.width < math.max(62, layout.fontHeight * 4)
            or node.height < layout.fontHeight + 6
            or node.x < 0 or node.y < 0
            or node.x + node.width > layout.width
            or node.y + node.height > layout.height then return false end
        local gun = layout.gun
        if node.x < gun.x + gun.width and gun.x < node.x + node.width
            and node.y < gun.y + gun.height and gun.y < node.y + node.height then return false end
        for _, other in pairs(layout.nodes) do
            if other ~= node and node.x < other.x + other.width and other.x < node.x + node.width
                and node.y < other.y + other.height and other.y < node.y + node.height then return false end
        end
    end
    return true
end

function W:layoutChildren()
    if not self.slots then return end
    local prefs, usable = self.layoutPrefs, self.width - 40
    local collapsed = prefs.weaponsCollapsed
    self.leftWidth = collapsed and 24 or math.floor(math.max(160, math.min(usable - 380, usable * prefs.leftRatio)))
    self.middleX = 20 + self.leftWidth
    local remaining = self.width - self.middleX - 20
    self.middleWidth = math.floor(math.max(200, math.min(remaining - 180, remaining * prefs.middleRatio)))
    self.optionsX = self.middleX + self.middleWidth + 10
    self.optionsWidth = self.width - self.optionsX - 10
    self.toolFontHeight = getTextManager():getFontHeight(UIFont.Small)
    self.toolBoxSize = math.max(48, self.toolFontHeight * 2 + 12)
    self.cartY = self.height - 146
    self.cartLabelY = self.cartY - self.toolFontHeight - 4
    self.toolY = self.cartLabelY - self.toolBoxSize - 8
    self.toolLabelY = self.toolY - self.toolFontHeight - 6
    self.statusY = self.toolLabelY - self.toolFontHeight - 8
    local bottom = self.statusY - 8
    self.panelHeight = math.max(48, bottom - 66)
    local diagramHeight = math.max(32, math.min(self.panelHeight - 56,
        math.floor(self.panelHeight * prefs.diagramRatio)))
    bounds(self.searchEntry, 10, 66, self.leftWidth, 26)
    bounds(self.weapons, 10, 99, self.leftWidth, bottom - 99)
    self.searchEntry:setVisible(not collapsed); self.weapons:setVisible(not collapsed)
    if collapsed and self.weapons.tooltipUI then
        self.weapons.tooltipUI:setVisible(false); self.weapons.tooltipUI:removeFromUIManager()
    end
    bounds(self.diagram, self.middleX, 66, self.middleWidth, diagramHeight)
    self.compactCenter = not self:diagramFits()
    self.diagram:setVisible(not self.compactCenter)
    if self.compactCenter then self.diagram:clearModelPreview() end
    local slotsY = self.compactCenter and 66 or 74 + diagramHeight
    bounds(self.slots, self.middleX, slotsY, self.middleWidth, bottom - slotsY - (self.compactCenter and 8 or 0))
    self.mountHeight = math.min(92, math.floor(self.panelHeight * 0.3))
    self.partsY = 66 + self.mountHeight + 30
    bounds(self.mounts, self.optionsX, 66, self.optionsWidth, self.mountHeight)
    bounds(self.parts, self.optionsX, self.partsY, self.optionsWidth, bottom - self.partsY)
    bounds(self.cart, 10, self.cartY, self.width - 20, 100)
    bounds(self.weaponToggle, 10, 38, 24, 24)
    self.weaponToggle:setTitle(collapsed and ">" or "<")
    self.weaponToggle.tooltip = tr(collapsed and "ShowWeapons" or "HideWeapons")
    bounds(self.leftDivider, self.middleX - 9, 66, 8, self.panelHeight)
    self.leftDivider:setVisible(not collapsed)
    bounds(self.middleDivider, self.optionsX - 9, 66, 8, self.panelHeight)
    -- Retain a bottom grip in compact mode to adjust the preferred diagram height.
    bounds(self.diagramDivider, self.middleX, self.compactCenter and bottom - 8 or 66 + diagramHeight,
        self.middleWidth, 8)
    for _, button in ipairs({self.applyButton,self.refreshButton,self.clearButton,self.resetLayoutButton,self.footerCloseButton}) do
        button:setY(self.height - 42)
    end
    self.footerCloseButton:setX(self.width - 130)
    self.layoutWidth, self.layoutHeight, self.layoutView = self.width, self.height, self.view
    self.layoutFont = self.toolFontHeight
end

function W:saveLayout()
    local p = self.layoutPrefs
    p.x, p.y, p.width, p.height = self.x, self.y, self.width, self.height
    LayoutPreferences.save(self.player:getPlayerNum(), p)
    self.layoutX, self.layoutY = self.x, self.y
    self.layoutSaveFrames = nil
end
function W:toggleWeapons()
    self.layoutPrefs.weaponsCollapsed = not self.layoutPrefs.weaponsCollapsed
    self:layoutChildren(); self:saveLayout()
end
function W:resetLayout()
    self.layoutPrefs = LayoutPreferences.defaults(getCore():getScreenWidth(), getCore():getScreenHeight())
    local p = self.layoutPrefs
    self:setX(p.x); self:setY(p.y); self:setWidth(p.width); self:setHeight(p.height)
    self.compactCenter = false
    self:layoutChildren(); self:saveLayout()
end
function W:resizeLayout(width, height)
    local values = {}
    for key,value in pairs(self.layoutPrefs) do values[key] = value end
    values.x, values.y, values.width, values.height = self.x, self.y, width, height
    values = LayoutPreferences.sanitize(values, getCore():getScreenWidth(), getCore():getScreenHeight())
    self:setX(values.x); self:setY(values.y)
    self:setWidth(values.width); self:setHeight(values.height)
    self:layoutChildren()
    self.layoutSaveFrames = 30
end

function W:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.layoutPrefs = self.layoutPrefs or LayoutPreferences.defaults(getCore():getScreenWidth(), getCore():getScreenHeight())
    local function list(x, y, width, height, rowHeight, draw)
        local box = ISScrollingListBox:new(x, y, width, height)
        box:initialise(); box:instantiate()
        box.itemheight = rowHeight
        box.doDrawItem = draw
        box.gmawWindow = self
        box.updateTooltip = updateItemTooltip
        self:addChild(box)
        return box
    end
    local usable = self.width - 40
    self.leftWidth = math.floor(usable * 0.23)
    self.middleWidth = math.floor(usable * 0.52)
    self.middleX = 20 + self.leftWidth
    self.optionsX = self.middleX + self.middleWidth + 10
    self.optionsWidth = self.width - self.optionsX - 10
    self.cartY = self.height - 146
    self.toolFontHeight = getTextManager():getFontHeight(UIFont.Small)
    self.toolBoxSize = math.max(48, self.toolFontHeight * 2 + 12)
    self.cartLabelY = self.cartY - self.toolFontHeight - 4
    self.toolY = self.cartLabelY - self.toolBoxSize - 8
    self.toolLabelY = self.toolY - self.toolFontHeight - 6
    self.statusY = self.toolLabelY - self.toolFontHeight - 8
    local panelBottom = self.statusY - 8
    local panelHeight = panelBottom - 66
    -- On small displays, preserve a usable diagram instead of giving most of
    -- the remaining height to the scrolling slot list.
    local diagramReserve=math.max(48,math.min(136,math.floor(panelHeight*0.27)))
    local diagramHeight = math.min(375, panelHeight - diagramReserve)
    self.searchEntry = ISTextEntryBox:new("", 10, 66, self.leftWidth, 26)
    self.searchEntry:initialise(); self.searchEntry:instantiate()
    self.searchEntry:setPlaceholderText(tr("Search"))
    self.searchEntry.target = self
    self.searchEntry.onTextChangeFunction = W.filterWeapons
    self:addChild(self.searchEntry)
    self.weapons = list(10, 99, self.leftWidth, panelBottom - 99, 66, drawItem)
    self.diagram = D:new(self.middleX, 66, self.middleWidth, diagramHeight)
    self.diagram.window = self
    self.diagram:initialise(); self.diagram:instantiate(); self:addChild(self.diagram)
    self.slots = list(self.middleX, 74 + diagramHeight, self.middleWidth,
        panelHeight - diagramHeight - 8, 74, drawSlot)
    self.mountHeight = math.min(92, math.floor(panelHeight * 0.3))
    self.partsY = 66 + self.mountHeight + 30
    self.mounts = list(self.optionsX, 66, self.optionsWidth, self.mountHeight, 66, drawItem)
    self.parts = list(self.optionsX, self.partsY, self.optionsWidth,
        panelBottom - self.partsY, 66, drawItem)
    -- Keep partial rows inside this viewport even when the list stencil alone
    -- does not hide their draw calls while scrolling.
    self.parts.clipTop = true
    self.cart = list(10, self.cartY, self.width - 20, 100, 66, drawItem)
    self.weapons:setOnMouseDownFunction(self, W.selectWeapon)
    self.slots:setOnMouseDownFunction(self, W.selectSlot)
    self.slots:setOnMouseDoubleClick(self, W.removePart)
    self.slots.onMouseDown = function(box, x, y)
        local index = box:rowAt(x, y)
        local row = box.items[index]
        local rowY = (index - 1) * box.itemheight
        if row and x >= box.width - 50 and x <= box.width - 26
            and y >= rowY + 7 and y <= rowY + 31 then
            self:removePart(row.item)
            return true
        end
        return ISScrollingListBox.onMouseDown(box, x, y)
    end
    self.mounts:setOnMouseDownFunction(self, W.choosePart)
    self.parts:setOnMouseDownFunction(self, W.choosePart)
    local function button(x, width, key, callback)
        local b = ISButton:new(x, self.height - 42, width, 26, tr(key), self, callback)
        b:initialise(); b:instantiate(); self:addChild(b)
        return b
    end
    self.applyButton = button(10, 150, "Apply", W.apply)
    self.refreshButton = button(170, 120, "Refresh", W.reload)
    self.clearButton = button(300, 120, "Clear", W.clear)
    self.footerCloseButton = button(self.width - 130, 120, "Close", W.close)
    self.resetLayoutButton = button(430, 140, "ResetLayout", W.resetLayout)
    self.weaponToggle = button(10, 24, "HideWeapons", W.toggleWeapons)
    local function divider(axis)
        local d = Divider:new(0, 0, 8, 8)
        d.window, d.axis, d.tooltip = self, axis, tr("ResizePanels")
        d:initialise(); d:instantiate(); self:addChild(d)
        return d
    end
    self.leftDivider, self.middleDivider, self.diagramDivider = divider("left"), divider("middle"), divider("diagram")
    if self.resizeWidget then self.resizeWidget.resizeFunction = W.resizeLayout end
    if self.resizeWidget2 then self.resizeWidget2.resizeFunction = W.resizeLayout end
    self:reload()
    self:layoutChildren()
end

function W:refreshTools(scan)
    scan = scan or S.scan(self.player)
    self.screwdriver = S.firstWorkingTag(scan, {ItemTag and ItemTag.SCREWDRIVER})
    self.wrench = S.firstWorkingTag(scan, {ItemTag and ItemTag.WRENCH, ItemTag and ItemTag.PIPE_WRENCH})
end

function W:resetView(code)
    self.target, self.plan, self.choices, self.activeSlot = nil, nil, {}, nil
    self.view = nil
    self.slots:clear(); self.mounts:clear(); self.parts:clear(); self.cart:clear()
    self.applyButton:setEnable(false); self.status = tr(code)
end

function W:selectWeapon(entry)
    if self.pending then return end
    self.target, self.choices, self.plan, self.activeSlot = entry, {}, nil, nil
    self.expected = M.fingerprint(entry.item)
    local ok, catalog = pcall(M.candidates, entry.item)
    if not ok then self:resetView("Unsupported"); return end
    self.catalog = catalog
    self.status = tr("Hint")
    for i, row in ipairs(self.weapons.items) do if row.item == entry then self.weapons.selected = i end end
    self:rebuild()
end

function W:reload()
    if self.pending then return end
    local ok, scan = pcall(S.scan, self.player)
    if not ok then self:resetView("Unsupported"); return end
    self.scan = scan
    self:refreshTools(scan)
    self:filterWeapons()
end

function W:filterWeapons()
    if not self.scan or self.pending then return end
    local wanted = self.target and self.target.item:getID() or self.initialID
    local query = self.searchEntry:getText():lower()
    self.weapons:clear()
    local selection
    for _, entry in ipairs(self.scan.entries) do
        if M.canOpen(entry.item) and entry.item:getName():lower():find(query, 1, true) then
            entry.subtitle = tr(entry.kind)
            self.weapons:addItem(entry.item:getName(), entry, entry.item:getName() .. " <LINE> " .. entry.subtitle)
            if entry.item:getID() == wanted then selection = entry end
        end
    end
    selection = selection or (self.weapons.items[1] and self.weapons.items[1].item)
    if selection then self:selectWeapon(selection) else self:resetView("NoWeapon") end
end

function W:choiceList(extra)
    return V.choices(self.choices, self.catalog, extra)
end

function W:selectSlot(card)
    if self.pending then return end
    self.activeSlot = card.slot
    for index, row in ipairs(self.slots.items) do
        if row.item == card then self.slots.selected = index; break end
    end
    self:showOptions()
end

function W:addOption(list, option)
    if option.current then option.subtitle = tr("Installed")
    elseif option.queued then option.subtitle = tr("Queued")
    elseif option.quantity == 0 then option.subtitle = tr("NotOwned")
    elseif option.dim then option.subtitle = tr(option.reason or "Unavailable")
    else option.subtitle = tr("Available") end
    if not option.current then
        option.subtitle = option.subtitle .. "  x" .. tostring(option.quantity)
    end
    local c = self.catalog[option.fullType]
    local parents = {}
    for _, parent in ipairs(M.keys(c.all)) do parents[#parents + 1] = getItemNameFromFullType(parent) end
    for _, parent in ipairs(M.keys(c.any)) do parents[#parents + 1] = getItemNameFromFullType(parent) end
    local tooltip = option.item:getName() .. " <LINE> " .. option.subtitle .. " <LINE> " .. tr(M.toolKey(option.item))
    if option.current then
        tooltip = tooltip .. " <LINE> " .. tr("Available") .. "  x" .. tostring(option.quantity)
    end
    if #parents > 0 then tooltip = tooltip .. " <LINE> " .. tr("Requires") .. ": " .. table.concat(parents, "/") end
    list:addItem(option.item:getName(), option, tooltip)
    if option.queued or option.current then list.selected = #list.items end
end

function W:showMounts()
    self.mounts:clear()
    if not self.view then return end
    for _, fullType in ipairs(M.keys(self.catalog)) do
        if M.isMountCandidate(self.catalog, fullType) then
            local card = self.view.bySlot[self.catalog[fullType].slot]
            if card then
                for _, option in ipairs(card.options) do
                    if option.fullType == fullType then self:addOption(self.mounts, option); break end
                end
            end
        end
    end
end

function W:showOptions()
    self.parts:clear()
    local card = self.view and self.view.bySlot[self.activeSlot]
    if not card then return end
    for _, option in ipairs(card.options) do
        if not M.isMountCandidate(self.catalog, option.fullType) then self:addOption(self.parts, option) end
    end
end

function W:rebuild()
    if not self.target then return end
    local scroll = self.slots:getYScroll()
    self.slots:clear(); self.cart:clear()
    self.view = V.build(self.catalog, M.installed(self.target.item), M.availability(self.catalog, self.scan),
        self.choices, self.player, self.target.item, self.scan)
    self.plan, self.reason = self.view.plan, self.view.reason
    if not self.view.bySlot[self.activeSlot] then self.activeSlot = self.view.slots[1] and self.view.slots[1].slot end
    for _, card in ipairs(self.view.slots) do
        local tooltip = tr("Slot_" .. card.slot) .. " <LINE> " .. tr("Installed") .. ": "
            .. (card.installed and card.installed:getName() or tr("Empty"))
        if card.queued then tooltip = tooltip .. " <LINE> " .. tr("Queued") .. ": " .. card.queued:getName() end
        self.slots:addItem(tr("Slot_" .. card.slot), card, tooltip)
        if card.slot == self.activeSlot then self.slots.selected = #self.slots.items end
    end
    self.slots:setYScroll(scroll)
    self:showMounts()
    self:showOptions()
    for _, step in ipairs(self.plan or {}) do
        local name = self.catalog[step.fullType].part:getName()
        local subtitle = tr(step.source.kind)
        if step.old then subtitle = subtitle .. " / " .. tr("Replace") .. ": " .. step.old:getName() end
        self.cart:addItem(name, {item=self.catalog[step.fullType].part, subtitle=subtitle}, name .. " <LINE> " .. subtitle)
    end
    if not self.plan then self.status = tr(self.reason)
    elseif #self.view.slots == 0 then self.status = tr("NoSlots") end
    self.applyButton:setEnable(not self.pending and self.plan ~= nil and #self.plan > 0)
end

function W:choosePart(row)
    if self.pending or not row.fullType then return end
    local slot = self.catalog[row.fullType].slot
    if row.current or self.choices[slot] == row.fullType then self.choices[slot] = nil
    elseif row.dim then self.status = tr(row.reason or "Missing"); return
    else self.choices[slot] = row.fullType end
    self.status = tr("Hint")
    self:rebuild()
end

function W:clear()
    if self.pending then return end
    self.choices = {}; self.status = tr("Hint"); self:rebuild()
end

function W:removePart(card)
    if self.pending or not card or not card.installed or not self.target then return end
    local ok, queued, reason = pcall(A.remove, self.player, self.target, self.expected, card.slot)
    if not ok then self.status = tr("Unsupported"); return end
    if not queued then self.status = tr(reason); return end
    self.pending = true
    self.applyButton:setEnable(false)
    self.status = tr("ActionsQueued")
end

function W:apply()
    if self.pending or not self.plan or #self.plan == 0 then return end
    local ok, queued, reason = pcall(A.begin, self.player, self.target, self.expected,
        self:choiceList(), P.signature(self.plan))
    if not ok then self.status = tr("Unsupported"); return end
    if not queued then self.status = tr(reason); return end
    self.pending = true
    self.applyButton:setEnable(false)
    self.status = tr("ActionsQueued")
end

function W:update()
    ISCollapsableWindow.update(self)
    if self.layoutX ~= self.x or self.layoutY ~= self.y then
        self.layoutX, self.layoutY = self.x, self.y
        self.layoutSaveFrames = 30
    end
    if self.layoutWidth ~= self.width or self.layoutHeight ~= self.height or self.layoutView ~= self.view
        or self.layoutFont ~= getTextManager():getFontHeight(UIFont.Small) then
        self:layoutChildren()
        self.layoutSaveFrames = 30
    end
    if self.layoutSaveFrames then
        self.layoutSaveFrames = self.layoutSaveFrames - 1
        if self.layoutSaveFrames <= 0 then self:saveLayout() end
    end
    self.toolRefreshFrames = (self.toolRefreshFrames or 0) + 1
    if self.toolRefreshFrames >= 30 then
        self.toolRefreshFrames = 0
        self:refreshTools()
    end
    -- A stale/pre-reload window can outlive the Actions script briefly.
    -- Rebind the published API and skip this frame rather than error-looping.
    A = GMAWActions or A
    if not A then return end
    local code = A.poll(self.player)
    if code then self:result(code)
    elseif A.busy(self.player) then
        self.pending = true
        self.applyButton:setEnable(false)
        self.status = tr("ActionsQueued")
    end
end

function W:result(code)
    self.pending = false
    self:reload()
    self.status = tr(code)
end

function W:drawToolStatus(x, width, source, fallback, name)
    local available = source ~= nil
    local red = available and 0.3 or 0.95
    local green = available and 0.9 or 0.2
    local size = self.toolBoxSize
    self:drawRect(x, self.toolY, width, size, 0.85, 0.08, 0.08, 0.08)
    self:drawRectBorder(x, self.toolY, width, size, 1, red, green, 0.2)
    local texture = toolTexture(source and source.item, fallback)
    if texture then
        local shade = available and 1 or 0.8
        self:drawTextureScaledAspect(texture, x + 4, self.toolY + 4, size - 8, size - 8,
            1, shade, shade, shade)
    end
    local textX, textWidth = x + size + 8, width - size - 16
    local textY = self.toolY + (size - self.toolFontHeight * 2 - 4) / 2
    self:drawText(fit(tr(name), textWidth), textX, textY, 0.95, 0.95, 0.95, 1, UIFont.Small)
    self:drawText(fit(tr(available and "ToolReady" or "ToolMissing"), textWidth),
        textX, textY + self.toolFontHeight + 4, red, green, 0.2, 1, UIFont.Small)
end

function W:prerender()
    ISCollapsableWindow.prerender(self)
    if not self.layoutPrefs.weaponsCollapsed then
        self:drawText(fit(tr("Weapons"), self.leftWidth - 32), 40, 42, 1, 1, 1, 1, UIFont.Small)
    end
    self:drawText(tr("Slots"), self.middleX, 42, 1, 1, 1, 1, UIFont.Small)
    self:drawText(fit(tr("Mounts"), self.mounts.width), self.optionsX, 42, 1, 1, 1, 1, UIFont.Small)
    local label = self.activeSlot and tr("Slot_" .. self.activeSlot) or tr("Options")
    self:drawText(fit(label, self.parts.width), self.optionsX, self.partsY - 21, 1, 1, 1, 1, UIFont.Small)
    self:drawText(fit(self.status or tr("ChooseSlot"), self.width - 20), 10, self.statusY, 1, 0.85, 0.5, 1, UIFont.Small)
    self:drawText(tr("ToolStatus"), 10, self.toolLabelY, 0.8, 0.8, 0.8, 1, UIFont.Small)
    local toolWidth = math.min(math.floor((self.width - 30) / 2), math.max(240, self.toolBoxSize + self.toolFontHeight * 12))
    self:drawToolStatus(10, toolWidth, self.screwdriver, "Item_Screwdriver", "ToolScrewdriver")
    self:drawToolStatus(20 + toolWidth, toolWidth, self.wrench, "Item_Wrench", "ToolWrench")
    self:drawText(tr("Cart"), 10, self.cartLabelY, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function W:close()
    self:saveLayout()
    self.diagram:clearModelPreview()
    for _, list in ipairs({self.weapons, self.slots, self.mounts, self.parts, self.cart}) do
        if list.tooltipUI then list.tooltipUI:setVisible(false); list.tooltipUI:removeFromUIManager() end
    end
    self:setVisible(false); self:removeFromUIManager()
    GMAWWindows[self.player:getPlayerNum()] = nil
end

function W.open(player, weapon)
    local number = player:getPlayerNum()
    if GMAWWindows[number] then GMAWWindows[number]:close() end
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local prefs = LayoutPreferences.load(number, sw, sh)
    local o = W:new(prefs.x, prefs.y, prefs.width, prefs.height)
    o.layoutPrefs = prefs
    o.minimumWidth, o.minimumHeight = math.min(720, sw - 30), math.min(600, sh - 40)
    o.player, o.initialID = player, weapon:getID()
    o.title, o.resizable = tr("Title"), true
    o:initialise(); o:addToUIManager()
    GMAWWindows[number] = o
end

Events.OnFillInventoryObjectContextMenu.Add(function(number, context, items)
    if not M.enabled() then return end
    for _, selected in ipairs(items) do
        local item = instanceof(selected, "InventoryItem") and selected or (selected.items and selected.items[1])
        if M.canOpen(item) then
            context:addOption(tr("Open"), getSpecificPlayer(number), W.open, item)
            return
        end
    end
end)

return W
