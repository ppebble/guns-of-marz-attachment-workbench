local L=require "GMAW/UI/LayoutPreferences"
local oldReader,oldWriter,oldCore=getFileReader,getFileWriter,getCore
local files,closed={},0
getCore=function() return {getScreenWidth=function() return 1920 end,getScreenHeight=function() return 1080 end} end
getFileWriter=function(name,create,append)
    assert(create and not append); files[name]=""
    return {write=function(_,s) files[name]=files[name]..s end,close=function() closed=closed+1 end}
end
getFileReader=function(name)
    if not files[name] then return nil end
    local lines={}; for line in files[name]:gmatch("[^\n]+") do lines[#lines+1]=line end
    local i=0
    return {readLine=function() i=i+1; return lines[i] end,close=function() closed=closed+1 end}
end
local initial=L.load(0,1920,1080)
assert(not initial.weaponsCollapsed and initial.width==1240)
initial.x=90; initial.y=100; initial.width=1100; initial.height=720
initial.leftRatio=0.3; initial.middleRatio=0.6; initial.diagramRatio=0.5; initial.weaponsCollapsed=true
assert(L.save(0,initial))
local loaded=L.load(0,1920,1080)
for key,value in pairs(initial) do assert(loaded[key]==value,"Layout round trip: "..key) end
assert(not L.load(1,1920,1080).weaponsCollapsed,"Split-screen profiles must stay independent")
local small=L.load(0,800,600)
assert(small.x+small.width<=800 and small.y+small.height<=600)
local invalid=L.sanitize({x=math.huge,y=-500,width=-1,height=0/0,leftRatio=7,middleRatio=-4},1280,720)
assert(invalid.width==720 and invalid.height==680 and invalid.y==0)
assert(invalid.leftRatio==0.4 and invalid.middleRatio==0.3)
files['GMAW-layout-v1-player0.ini']='version=99\nweaponsCollapsed=true\nwidth=1\n'
assert(not L.load(0,1920,1080).weaponsCollapsed,"Unknown versions use defaults")
files['GMAW-layout-v1-player0.ini']='version=1\nwidth=broken\nx=999999\nweaponsCollapsed=false\n'
assert(L.load(0,1920,1080).width==1240)
assert(L.load(0,1920,1080).x==680)
getFileReader=function() error('read failure') end
assert(L.load(0,1920,1080).width==1240)
getFileWriter=function() error('write failure') end
assert(not L.save(0,initial),"I/O failure must not break the workbench")
assert(closed>0)
getFileReader, getFileWriter, getCore=oldReader,oldWriter,oldCore
print('PASS local layout round trip, profile isolation, malformed data, screen clamp and I/O failure')
