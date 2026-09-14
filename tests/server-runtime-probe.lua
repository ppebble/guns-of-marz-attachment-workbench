-- Private smoke-test mod only. Never included in Contents or Workshop staging.
Events.OnServerStarted.Add(function()
    local ok, why = pcall(function()
        assert(isServer() and not isClient(), "not a dedicated-server environment")
        local M = require "GMAW/Model"
        assert(M.enabled(), "GoM runtime gate disabled")
        local gun = assert(instanceItem("MarzGuns.M4A1"))
        assert(M.supported(gun), "server cannot identify the firearm owner")
        local candidates = M.candidates(gun)
        assert(candidates["Base.Silencer"], "ISIL missing on server")
        assert(candidates["SimpleSuppressors.Suppressor_556"], "Simple Suppressors missing on server")
        assert(not candidates["SimpleSuppressors.Suppressor_9mm"], "server accepted wrong caliber")
        assert(M.candidates(instanceItem("MarzGuns.M1911"))["SimpleSuppressors.Suppressor_45ACP"], "45 ACP missing")
        local count = 0
        local T = require "GMAW/Attachments"
        for _, part in pairs(M.catalog()) do if T.owner(part) then count=count+1 end end
        assert(count==21, "unexpected addon count: " .. tostring(count))
        -- A private, unconnected Java player exercises server-side action code.
        -- This is stronger than table mocks, but not a connected client test.
        local player = IsoPlayer.new(getCell())
        local inventory = player:getInventory()
        inventory:AddItem(gun)
        inventory:AddItem("Base.Screwdriver")
        local authority = require "GMAW/Authority"
        for _, fullType in ipairs({"SimpleSuppressors.Suppressor_556", "Base.Silencer"}) do
            local part = inventory:AddItem(fullType)
            local slot = part:getPartType()
            local initial = gun:getWeaponPart(slot)
            if initial then gun:detachWeaponPart(player, initial) end -- private fixture only
            local applied, reason = authority.apply(player, {kind="install",weaponID=gun:getID(),
                partID=part:getID(),slot=slot,fullType=fullType})
            assert(applied, fullType .. " install rejected: " .. tostring(reason))
            assert(gun:getWeaponPart(slot)==part and not inventory:contains(part), "install postcondition")
            applied, reason = authority.apply(player, {kind="detach",weaponID=gun:getID(),partID=part:getID(),slot=slot})
            assert(applied, fullType .. " removal rejected: " .. tostring(reason))
            assert(not gun:getWeaponPart(slot) and inventory:contains(part), "remove postcondition")
        end
        print("[GMAW-SERVER-SMOKE] PASS dedicated runtime, real Java player/items, both addon install/remove, 21 definitions, caliber gates, owner=" .. tostring(gun:getModID()))
    end)
    if not ok then print("[GMAW-SERVER-SMOKE] FAIL " .. tostring(why)) end
end)
