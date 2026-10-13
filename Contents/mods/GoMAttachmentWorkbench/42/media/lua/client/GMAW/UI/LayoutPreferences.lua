-- Client-local preferences, independent of saves, servers and character ModData.
local L = {}
local fields = {"x", "y", "width", "height", "leftRatio", "middleRatio", "diagramRatio"}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function clamp(value, fallback, low, high)
    if not finite(value) then value = fallback end
    return math.max(low, math.min(high, value))
end
function L.defaults(sw, sh)
    return {x=15, y=20, width=math.min(1240, sw-30), height=math.min(850, sh-40),
        leftRatio=0.23, middleRatio=0.675, diagramRatio=0.73, weaponsCollapsed=false}
end
function L.sanitize(data, sw, sh)
    local d = L.defaults(sw, sh)
    data = type(data) == "table" and data or {}
    local maxWidth, maxHeight = math.max(1, sw-30), math.max(1, sh-40)
    local result = {
        width=math.floor(clamp(data.width, d.width, math.min(720, maxWidth), maxWidth)),
        height=math.floor(clamp(data.height, d.height, math.min(600, maxHeight), maxHeight)),
        leftRatio=clamp(data.leftRatio, d.leftRatio, 0.12, 0.4),
        middleRatio=clamp(data.middleRatio, d.middleRatio, 0.3, 0.8),
        diagramRatio=clamp(data.diagramRatio, d.diagramRatio, 0.2, 0.85),
        weaponsCollapsed=data.weaponsCollapsed == true,
    }
    result.x=math.floor(clamp(data.x, d.x, 0, math.max(0, sw-result.width)))
    result.y=math.floor(clamp(data.y, d.y, 0, math.max(0, sh-result.height)))
    return result
end
local function filename(playerNumber)
    local index=math.floor(clamp(playerNumber, 0, 0, 3))
    return "GMAW-layout-v1-player" .. index .. ".ini"
end
function L.load(playerNumber, sw, sh)
    if not getFileReader then return L.sanitize(nil, sw, sh) end
    local reader
    local ok, data = pcall(function()
        reader=getFileReader(filename(playerNumber), false)
        if not reader then return {} end
        local values={}
        for i=1,32 do
            local line=reader:readLine()
            if not line then break end
            local key, value=line:match("^(%w+)=(.*)$")
            if key then values[key]=value end
        end
        if values.version ~= "1" then return {} end
        local parsed={weaponsCollapsed=values.weaponsCollapsed == "true"}
        for _,key in ipairs(fields) do parsed[key]=tonumber(values[key]) end
        return parsed
    end)
    if reader then pcall(function() reader:close() end) end
    return L.sanitize(ok and data or nil, sw, sh)
end
function L.save(playerNumber, data)
    if not getFileWriter then return false end
    local core=getCore()
    local values=L.sanitize(data, core:getScreenWidth(), core:getScreenHeight())
    local writer
    local ok=pcall(function()
        writer=getFileWriter(filename(playerNumber), true, false)
        if not writer then error("Cannot open local workbench preferences") end
        writer:write("version=1\n")
        for _,key in ipairs(fields) do writer:write(key .. "=" .. tostring(values[key]) .. "\n") end
        writer:write("weaponsCollapsed=" .. tostring(values.weaponsCollapsed) .. "\n")
    end)
    local closed=true
    if writer then closed=pcall(function() writer:close() end) end
    return ok and closed
end
return L
