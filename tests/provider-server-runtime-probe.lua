-- Private isolated dedicated runtime probe. Never shipped in Contents.
Events.OnServerStarted.Add(function()
    local ok, why = pcall(function()
        assert(isServer() and not isClient(), "not dedicated server")
        local M,T,A = require "GMAW/Model", require "GMAW/Attachments", require "GMAW/Authority"
        local gael = GMAWSmokeProvider == "Gael"
        assert(M.enabled(), "provider disabled")
        if gael then
            assert(not getActivatedMods():contains("SWMG") and not getActivatedMods():contains("GunsOfMarz"), "Gael smoke contaminated by GoM")
        end
        local player = IsoPlayer.new(getCell())
        local inv = player:getInventory()
        local gun = assert(inv:AddItem(gael and "Base.AK47" or "ENF2.AR15"))
        assert(M.supported(gun), "owner gate: " .. tostring(gun:getModID()))
        -- Clear randomized OnCreate attachments on this fresh private fixture.
        local parts = gun:getAllWeaponParts()
        for i=parts:size()-1,0,-1 do gun:detachWeaponPart(player,parts:get(i)) end
        local screwdriver = inv:AddItem("Base.Screwdriver")
        inv:AddItem("Base.Wrench")
        local catalog=M.candidates(gun)
        local function install(fullType)
            local c=assert(catalog[fullType], "catalog missing "..fullType)
            local part=assert(inv:AddItem(c.consume))
            local applied,reason=A.apply(player,{kind="install",weaponID=gun:getID(),partID=part:getID(),
                slot=c.slot,fullType=fullType,generic=c.consume~=fullType})
            assert(applied,"install "..fullType..": "..tostring(reason))
            assert(gun:getWeaponPart(c.slot):getFullType()==fullType and not inv:contains(part),"install postcondition "..fullType)
            return gun:getWeaponPart(c.slot)
        end
        local function remove(part)
            local applied,reason=A.apply(player,{kind="detach",weaponID=gun:getID(),partID=part:getID(),slot=part:getPartType()})
            assert(applied,"remove "..part:getFullType()..": "..tostring(reason))
            assert(not gun:getWeaponPart(part:getPartType()),"remove postcondition")
        end
        if gael then
            local scope=inv:AddItem("Base.Accupoint")
            local request={kind="install",weaponID=gun:getID(),partID=scope:getID(),slot="Scope",fullType=scope:getFullType()}
            assert(not A.apply(player,request),"scope accepted without mount")
            local mount=install("Base.AkMount")
            inv:Remove(screwdriver)
            assert(not A.apply(player,request),"missing screwdriver accepted")
            inv:AddItem(screwdriver)
            local condition=screwdriver:getCondition()
            screwdriver:setCondition(0)
            assert(not A.apply(player,request),"broken screwdriver accepted")
            screwdriver:setCondition(condition)
            assert(A.apply(player,request),"scope rejected after mount and tool")
            assert(gun:getWeaponPart("Scope")==scope and not inv:contains(scope),"exact Gael scope identity")
            inv:Remove(screwdriver)
            assert(not A.apply(player,{kind="detach",weaponID=gun:getID(),partID=scope:getID(),slot="Scope"}),"missing removal screwdriver accepted")
            inv:AddItem(screwdriver)
            assert(not A.apply(player,{kind="detach",weaponID=gun:getID(),partID=mount:getID(),slot="Mount"}),"parent removed with child")
            remove(scope); remove(mount)
            assert(inv:contains(scope) and inv:contains(mount),"Gael refunds exact instances")
            local launcher=inv:AddItem("Base.GP30_GL")
            assert(not catalog[launcher:getFullType()],"stateful launcher entered catalog")
            assert(not A.apply(player,{kind="install",weaponID=gun:getID(),partID=launcher:getID(),slot="Stool",fullType=launcher:getFullType()}),"stateful launcher accepted")
            assert(inv:contains(launcher),"launcher consumed on denial")
            -- Gael intentionally redefines Base.Pistol; the script namespace
            -- does not make it vanilla. Verify actual runtime ownership.
            local pistol=instanceItem("Base.Pistol")
            assert(pistol:getModID()=="GaelGunStore_B42" and M.supported(pistol),"Gael redefined pistol owner")
        else
            local rail=install("MarzGuns.Picatinny_Rail_Up")
            remove(rail)
            assert(inv:contains("MarzGuns.Picatinny_Rail"),"native generic rail refund missing")
            local foreign=assert(inv:AddItem("Base.Hammer"),"known non-attachment fixture")
            local applied=A.apply(player,{kind="install",weaponID=gun:getID(),partID=foreign:getID(),slot="Scope",fullType=foreign:getFullType()})
            assert(not applied and inv:contains(foreign),"Emre forged part accepted or consumed")
        end
        print("[GMAW-SERVER-SMOKE] PASS "..GMAWSmokeProvider.." dedicated runtime, real Java player/items, native authority install/remove, dependency/tool/owner gates; no connected client")
    end)
    if not ok then print("[GMAW-SERVER-SMOKE] FAIL "..tostring(why)) end
end)
