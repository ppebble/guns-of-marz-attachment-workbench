local W,S = require "GMAW/Window", require "GMAW/Sources"
local savedScan = S.scan
S.scan = function() return {entries={},byID={},byType={}} end
local w=W:new(15,20,1120,820)
w.player={getPlayerNum=function() return 0 end}
w:createChildren()
S.scan=savedScan
local texture={getWidth=function() return 512 end,getHeight=function() return 256 end,
    getWidthOrig=function() return 32 end,getHeightOrig=function() return 32 end}
local gun=item("Base.SVD",9900)
gun.getTex=function() return texture end
gun.getName=function() return "SVD" end
gun.getModID=function() return "GaelGunStore_B42" end
gun.isTwoHandWeapon=function() return true end
local scaled
w.weapons.drawTextureScaled=function(_,tex,x,y,width,height)
    scaled={x=x,y=y,width=width,height=height}
end
w.weapons:doDrawItem(0,{index=1,text="SVD",item={item=gun}})
assert(scaled and scaled.width<=42 and scaled.height<=42,
    "live texture dimensions, not original icon dimensions, bound the weapon-list icon")
assert(scaled.x+scaled.width<=53 and scaled.y+scaled.height<=53,"icon cannot spill over gun name")

local d=w.diagram
w.target={item=gun};w.view={slots={}};w.activeSlot=nil
d.getAbsoluteX=function() return 280 end;d.getAbsoluteY=function() return 86 end
d.setStencilRect=function() end;d.clearStencilRect=function() end;d.repaintStencilRect=function() end
local actual
d.drawTextureAllPoint=function(_,tex,...)
    actual={...}
end
local square={getWidth=function() return 32 end,getHeight=function() return 32 end}
local generated={getWidth=function() return 512 end,getHeight=function() return 512 end,
    getWidthOrig=function() return 32 end,getHeightOrig=function() return 32 end}
assert(not d:weaponQuad(gun,generated,d:cardLayout()),"generated thumbnails must not inherit static icon rotation")
gun.getTex=function() return square end
local q=d:weaponQuad(gun,square,d:cardLayout())
d:prerender()
assert(actual and actual[1]==q[1].x+280 and actual[2]==q[1].y+86,
    "rotated gun vertices use screen coordinates, not panel-local coordinates")
for i=1,4 do
    assert(actual[i*2-1]==q[i].x+280 and actual[i*2]==q[i].y+86,"all quad corners follow window movement")
end
d.getAbsoluteX=function() return 480 end;d.getAbsoluteY=function() return 186 end
d:prerender()
assert(actual[1]==q[1].x+480 and actual[2]==q[1].y+186,"moving the workbench keeps the gun in its panel")
