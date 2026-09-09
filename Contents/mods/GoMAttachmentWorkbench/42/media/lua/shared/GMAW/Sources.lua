local S = {}

-- Stable source keys contain server-resolved positions/indices, not client object references.
-- Order: player (recursive), floor, furniture, vehicle; each then sorted by key/item ID.
function S.scan(player)
    local result = { entries = {}, byID = {}, byType = {} }
    local seenContainers, seenItems, seenVehicles = {}, {}, {}
    local visit
    local function itemEntry(item, key, kind, container, world, depth)
        if not item or seenItems[item:getID()] then return end
        seenItems[item:getID()] = true
        if container and not container:isRemoveItemAllowed(item) then return end
        local e = { item = item, key = key, kind = kind, container = container, world = world }
        result.entries[#result.entries + 1] = e
        if depth < 8 and instanceof(item, "InventoryContainer") then
            visit(item:getInventory(), key .. "/bag:" .. tostring(item:getID()), kind, depth + 1)
        end
    end
    visit = function(container, key, kind, depth)
        if not container or seenContainers[container] then return end
        seenContainers[container] = true
        local items = container:getItems()
        for i = 0, items:size() - 1 do itemEntry(items:get(i), key, kind, container, nil, depth) end
    end
    visit(player:getInventory(), "0:player", "Player", 0)
    local current = player:getCurrentSquare()
    if not current then return result end
    local x, y, z = current:getX(), current:getY(), current:getZ()
    for dy = -1, 1 do
        for dx = -1, 1 do
            local square = getCell():getGridSquare(x + dx, y + dy, z)
            if square and (square == current or current:canReachTo(square))
                and (not (isClient() or isServer()) or SafeHouse.isSafehouseAllowLoot(square, player)) then
                local pos = tostring(x + dx) .. ":" .. tostring(y + dy) .. ":" .. tostring(z)
                local worlds = square:getWorldObjects()
                for i = 0, worlds:size() - 1 do
                    local world = worlds:get(i)
                    itemEntry(world:getItem(), "1:floor:" .. pos, "Floor", nil, world, 0)
                end
                local objects = square:getObjects()
                for i = 0, objects:size() - 1 do
                    local object = objects:get(i)
                    if not (instanceof(object, "IsoThumpable") and object:isLockedToCharacter(player)) then
                        for c = 0, object:getContainerCount() - 1 do
                            visit(object:getContainerByIndex(c), "2:object:" .. pos .. ":" .. i .. ":" .. c, "Furniture", 0)
                        end
                    end
                end
                -- Carts and other movable storage can be static-moving objects,
                -- not square objects.  Vanilla inventory discovery scans both.
                local statics = square.getStaticMovingObjects and square:getStaticMovingObjects()
                if statics then
                    for i = 0, statics:size() - 1 do
                        local object = statics:get(i)
                        if object and object.getContainer then
                            visit(object:getContainer(), "2:static:" .. pos .. ":" .. i, "Furniture", 0)
                        end
                    end
                end
                local vehicle = square:getVehicleContainer()
                if vehicle and not seenVehicles[vehicle] then
                    seenVehicles[vehicle] = true
                    for i = 0, vehicle:getPartCount() - 1 do
                        if vehicle:canAccessContainer(i, player) then
                            visit(vehicle:getPartByIndex(i):getItemContainer(),
                                "3:vehicle:" .. tostring(vehicle:getId()) .. ":" .. i, "Vehicle", 0)
                        end
                    end
                end
            end
        end
    end
    table.sort(result.entries, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.item:getID() < b.item:getID()
    end)
    for _, e in ipairs(result.entries) do
        local fullType = e.item:getFullType()
        result.byID[e.item:getID()] = e
        if not result.byType[fullType] then result.byType[fullType] = {} end
        if not e.item:isBroken() then table.insert(result.byType[fullType], e) end
    end
    return result
end

-- Uses the same bounded scan as parts. Tags match GoM's screwdriver/wrench
-- lookup, while the returned entry retains the exact source for native transfer.
function S.firstWorkingTag(scan, tags)
    for _, entry in ipairs(scan.entries or {}) do
        local item = entry.item
        if item and not item:isBroken() and item.hasTag then
            for _, tag in ipairs(tags or {}) do
                if tag and item:hasTag(tag) then return entry end
            end
        end
    end
    return nil
end

function S.hasWorkingGroups(scan, groups)
    for _, tags in ipairs(groups or {}) do
        if not S.firstWorkingTag(scan, tags) then return false end
    end
    return true
end

return S
