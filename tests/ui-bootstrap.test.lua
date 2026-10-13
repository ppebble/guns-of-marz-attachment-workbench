local UI = {}
function UI:derive()
    local derived = {}; setmetatable(derived, {__index=self}); derived.__index=derived; return derived
end
function UI:new(x,y,width,height)
    return setmetatable({x=x,y=y,width=width,height=height,items={},selected=0,scroll=0,draws={},enabled=true}, {__index=self})
end
function UI:initialise() end
function UI:instantiate() end
function UI:createChildren() end
function UI:addChild() end
function UI:removeChild() end
function UI:setX(v) self.x=v end
function UI:setY(v) self.y=v end
function UI:setWidth(v) self.width=v end
function UI:setHeight(v) self.height=v end
function UI:getX() return self.x end
function UI:getY() return self.y end
function UI:getWidth() return self.width end
function UI:getHeight() return self.height end
function UI:setCapture(value) self.capture=value end
function UI:setTitle(value) self.title=value end
function UI:onResize() end
function UI:addToUIManager() if not self.created then self.created=true; self:createChildren() end end
function UI:removeFromUIManager() end
function UI:setVisible(value) self.visible=value end
function UI:bringToTop() end
function UI:setOwner(owner) self.owner=owner end
function UI:setItem(item) self.item=item end
function UI:setCharacter(character) self.character=character end
function UI:setEnable(value) self.enabled=value end
function UI:getText() return self.text or "" end
function UI:setText(value) self.text=value; if self.onTextChangeFunction then self.onTextChangeFunction(self.target,self) end end
function UI:setPlaceholderText(value) self.placeholder=value end
function UI:setOnMouseDownFunction(target,callback) self.target=target; self.callback=callback end
function UI:setOnMouseDoubleClick(target,callback) self.doubleCallback=callback end
function UI:rowAt(x,y) return math.floor(y/self.itemheight)+1 end
function UI:onMouseDown(x,y) self.callback(self.target,self.items[self:rowAt(x,y)].item) end
function UI:addItem(text,data,tooltip) self.items[#self.items+1]={index=#self.items+1,text=text,item=data,tooltip=tooltip} end
function UI:clear() self.items={}; self.selected=0 end
function UI:getYScroll() return self.scroll end
function UI:setYScroll(value) self.scroll=value end
function UI:isMouseOver() return self.mouseOver end
function UI:isMouseOverScrollBar() return false end
function UI:getMouseX() return self.mouseX or 0 end
function UI:getMouseY() return self.mouseY or 0 end
function UI:drawRect(x,y,w,h,a,r,g,b)
    self.draws[#self.draws+1]={x=x,y=y,width=w,height=h,alpha=a,r=r,g=g,b=b}
end
function UI:drawRectBorder(x,y,w,h,a,r,g,b) self.draws[#self.draws+1]={border=true,y=y,height=h,r=r,g=g,b=b} end
function UI:drawText(text,x,y) self.draws[#self.draws+1]={text=text,y=y} end
function UI:drawTextureScaledAspect(texture,x,y,w,h,alpha,r,g,b)
    assert(texture and w>0 and h>0)
    self.draws[#self.draws+1]={texture=texture,y=y,height=h,alpha=alpha,r=r}
end
function UI:prerender() end
function UI:update() end
ISCollapsableWindow=UI:derive(); ISScrollingListBox=UI:derive(); ISButton=UI:derive(); ISPanel=UI:derive()
function ISCollapsableWindow:createChildren()
    self.resizeWidget={target=self}
    self.resizeWidget2={target=self}
end
function ISButton:new(x,y,width,height,title,target,callback)
    local button=UI.new(self,x,y,width,height)
    button.title,button.target,button.onclick=title,target,callback
    return button
end
ISTextEntryBox=UI:derive()
function ISTextEntryBox:new(text,x,y,width,height)
    local box=UI.new(self,x,y,width,height); box.text=text; return box
end
ISToolTipInv=UI:derive()
ISUI3DScene=UI:derive()
function ISUI3DScene:instantiate()
    self.calls={}
    local function call(_,name,...)
        self.calls[#self.calls+1]={name=name,args={...}}
        if name=="getObjectTranslation" then return {set=function(_,x,y,z) self.translation={x,y,z} end} end
        if name=="getObjectScale" then return {set=function(_,x,y,z) self.modelScale={x,y,z} end} end
        if name=="getObjectRotation" then return {set=function(_,x,y,z) self.modelRotation={x,y,z} end} end
    end
    -- Native Right camera sceneToUI() projection used by UI visual anchors.
    -- The fake intentionally omits model mesh geometry: only transformation
    -- math can be checked here; actual visual alignment needs a game client.
    local function ppu()
        return self.width/1366*math.exp(13*0.2)*160/1.82
    end
    self.javaObject={fromLua1=call,fromLua2=call,fromLua3=call,fromLua4=call,
        -- Installed UI3DScene: Right = Y 90 degrees (Left = 270).
        sceneToUIX=function(_,x,y,z) return self.width/2+z*ppu() end,
        sceneToUIY=function(_,x,y,z) return self.height/2-y*ppu() end}
end
function ISUI3DScene:setView(v)
    self.view=v
    self.javaObject:fromLua1("setView",v)
end
modules["Vehicles/ISUI/ISUI3DScene"]=ISUI3DScene
function ISToolTipInv:new(item)
    local o=UI.new(self,0,0,0,0); o.item=item; return o
end
modules["ISUI/ISCollapsableWindow"]=ISCollapsableWindow
modules["ISUI/ISScrollingListBox"]=ISScrollingListBox
modules["ISUI/ISButton"]=ISButton
modules["ISUI/ISPanel"]=ISPanel
modules["ISUI/ISTextEntryBox"]=ISTextEntryBox
modules["ISUI/ISToolTipInv"]=ISToolTipInv
modules["MarzWeapons/ItemTooltipsTable"]={tooltipsPergun={
    ["MarzGuns.OKP3_Sight"]={"Aiming Time reduced by 5%", "Critical and Hit Chance increased by 15%", "Needs Screwdriver to install or remove."}
}}
UIFont={Small="Small"}
function getText(key) return key:gsub("^IGUI_GMAW_", "") end
function getTextManager() return {MeasureStringX=function(_,font,text) return #text*6 end,
    getFontHeight=function() return 14 end} end
function getCore() return {getScreenWidth=function() return 1086 end,getScreenHeight=function() return 642 end} end
function getSpecificPlayer(number) return {number=number} end
Events.OnFillInventoryObjectContextMenu={Add=function(callback) gmawInventoryMenu=callback end}
Events.OnServerCommand={Add=function(callback) uiServerCallback=callback end}
