-- Engine objects are mocked; compatibility modules below are actual installed Lua.
local active = {[installedModID]=true, ImprovisedSilencers=true, SimpleSuppressors=true}
function getActivatedMods() return {contains=function(_, id) return active[id] == true end} end
attachmentActive = active
ItemType = {WEAPON_PART="base:weaponpart", WEAPON="base:weapon", Weapon="base:weapon"}
ItemTag = {SCREWDRIVER="screwdriver",WRENCH="wrench",PIPE_WRENCH="pipe_wrench"}
SandboxVars = {SimpleSuppressors={}}
local events = {"OnGameBoot","OnGameStart","OnEquipPrimary","OnWeaponSwing","OnPlayerUpdate","OnWeaponSwingHitPoint","OnServerCommand"}
for _, name in ipairs(events) do Events[name] = {Add=function() end} end
modules["simple-suppressors/diagnostics"] = true
SimpleSuppressorsDiagnostics = {loaded=function() end,info=function() end,failure=function() end,
    guard=function(_, _, callback) return callback end}
modules["ISIL_ModelMounts"] = {ensure=function() return nil, "mocked models" end}
modules["WeaponSystems/Utils/CustomStatsAttachments"] = {RegisterRestoreStats=function() end,RegisterMultipleParts=function() end}
modules["WeaponSystems/Utils/StatsFactory"].Multiply=function() return {} end
modules["WeaponSystems/Utils/StatsFactory"].Set=function() return {} end
modules["WeaponSystems/Utils/Animations"] = {CallSyncHandWeaponFields=function() end}
for key, r in pairs(installedRecords) do r.owner=installedModID end
for key, r in pairs(addonRecords) do installedRecords[key]=r end
local scripts, byType, sequence = {}, {}, 50000
for key, r in pairs(installedRecords) do
    local record = r
    local script = {
        getModID=function() return record.owner end, getFullName=function() return record.fullType end,
        getModuleName=function() return record.fullType:match("^([^%.]+)") end,
        isItemType=function(_, t) return t == record.type end, isRanged=function() return record.type == "base:weapon" end,
        getObsolete=function() return false end, getSwingAnim=function() return record.swing end,
        getAmmoType=function() return record.ammo end, getWeaponSprite=function() return "" end,
        DoParam=function(_, param)
            local mounts = param:match("^MountOn%s*=%s*(.*)")
            if mounts then record.mounts={}; for name in mounts:gmatch("[^;]+") do record.mounts[#record.mounts+1]=name end end
        end,
    }
    scripts[#scripts+1], byType[key] = script, script
end
function getScriptManager() return {getAllItems=function() return javaList(scripts) end,
    getItem=function(_, key) return byType[key] end, getModelScript=function() return nil end} end
function instanceItem(key)
    local r=installedRecords[key]; if not r then return nil end
    sequence=sequence+1
    local p=item(key, sequence, r.slot)
    p.class=r.type == "base:weaponpart" and "WeaponPart" or "HandWeapon"
    p.parts={}
    p.getModID=function() return r.owner end
    p.getName=function() return key end
    p.getMountOn=function() return javaList(r.mounts) end
    p.isRanged=function() return r.type == "base:weapon" end
    p.getAmmoType=function() return {getItemKey=function() return ammoKeys[r.ammo] or r.ammo end} end
    p.getMagazineType=function() return "" end
    p.getWeaponReloadType=function() return "" end
    p.getWeaponPart=function(self, slot) return self.parts[slot] end
    p.getAllWeaponParts=function(self) local out={};for _, part in pairs(self.parts) do out[#out+1]=part end; return javaList(out) end
    p.attachWeaponPart=function(self, _, part) self.parts[part:getPartType()]=part end
    p.detachWeaponPart=function(self, _, part) self.parts[part:getPartType()]=nil end
    p.canAttach=function(self, player, weapon)
        local mount=false;for _, name in ipairs(r.mounts) do if name==weapon:getFullType() then mount=true end end
        if not mount then return false end
        if r.canAttach == "SimpleSuppressorsCompatibility.canAttach" then return SimpleSuppressorsCompatibility.canAttach(player, weapon, self) end
        return r.canAttach ~= "ItemCodeOnTest.hasScrewdriver" or player.hasScrewdriver
    end
    p.canDetach=function(_, player) return r.canDetach ~= "ItemCodeOnTest.hasScrewdriver" or player.hasScrewdriver end
    return p
end
