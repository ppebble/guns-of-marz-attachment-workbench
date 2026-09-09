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
function UI:addToUIManager() if not self.created then self.created=true; self:createChildren() end end
function UI:removeFromUIManager() end
function UI:setVisible() end
function UI:setEnable(value) self.enabled=value end
function UI:setOnMouseDownFunction(target,callback) self.target=target; self.callback=callback end
function UI:setOnMouseDoubleClick(target,callback) self.doubleCallback=callback end
function UI:rowAt(x,y) return math.floor(y/self.itemheight)+1 end
function UI:onMouseDown(x,y) self.callback(self.target,self.items[self:rowAt(x,y)].item) end
function UI:addItem(text,data,tooltip) self.items[#self.items+1]={index=#self.items+1,text=text,item=data,tooltip=tooltip} end
function UI:clear() self.items={}; self.selected=0 end
function UI:getYScroll() return self.scroll end
function UI:setYScroll(value) self.scroll=value end
function UI:drawRect() end
function UI:drawRectBorder(x,y,w,h,a,r,g,b) self.draws[#self.draws+1]={border=true,r=r,g=g,b=b} end
function UI:drawText(text) self.draws[#self.draws+1]={text=text} end
function UI:drawTextureScaledAspect(texture,x,y,w,h,alpha,r,g,b)
    assert(texture and w>0 and h>0)
    self.draws[#self.draws+1]={texture=texture,alpha=alpha,r=r}
end
function UI:prerender() end
function UI:update() end
ISCollapsableWindow=UI:derive(); ISScrollingListBox=UI:derive(); ISButton=UI:derive()
modules["ISUI/ISCollapsableWindow"]=ISCollapsableWindow
modules["ISUI/ISScrollingListBox"]=ISScrollingListBox
modules["ISUI/ISButton"]=ISButton
UIFont={Small="Small"}
function getText(key) return key:gsub("^IGUI_GMAW_", "") end
function getTextManager() return {MeasureStringX=function(_,font,text) return #text*6 end} end
function getCore() return {getScreenWidth=function() return 1086 end,getScreenHeight=function() return 642 end} end
Events.OnFillInventoryObjectContextMenu={Add=function() end}
Events.OnServerCommand={Add=function(callback) uiServerCallback=callback end}
