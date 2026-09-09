require "GMAW/NativeCompletion"
require "GMAW/Authority"
local Authority = require "GMAW/Authority"

local function syncWeapon(player, weapon)
    if syncHandWeaponFields then syncHandWeaponFields(player, weapon) end
    if sendItemStats then sendItemStats(weapon) end
    if sendReplaceItemInContainer then
        sendReplaceItemInContainer(player:getInventory(), weapon, weapon)
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= "GMAW" or command ~= "apply" then return end
    local invoked, applied, changed, direction = pcall(Authority.apply, player, args)
    if not invoked or not applied then
        print("[GMAW] server rejected " .. tostring(args and args.kind) .. ": " .. tostring(changed))
        return
    end
    local inventory = player:getInventory()
    if direction == "remove" then
        sendRemoveItemFromContainer(inventory, changed)
    else
        sendAddItemToContainer(inventory, changed)
    end
    local weapon = inventory:getItemById(args.weaponID)
    if weapon then syncWeapon(player, weapon) end
    print("[GMAW] server applied " .. tostring(args.kind) .. " weapon=" .. tostring(args.weaponID)
        .. " slot=" .. tostring(args.slot))
end

Events.OnClientCommand.Add(onClientCommand)
print("[GMAW] server authority loaded")
