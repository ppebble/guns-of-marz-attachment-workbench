-- Optional, part-only integration. Never infer ownership from the Base module.
local T = {}
local registeredSimple
local function simpleCompatibility()
    require "simple-suppressors/compatibility"
    local api = SimpleSuppressorsCompatibility
    if registeredSimple ~= api then
        -- Verified AmmoType item keys in current Gunworks and bundled old GoM.
        -- Upstream inference misses e.g. SWMG.45_Bullet; do not guess calibers
        -- from weapon names or remap unsupported cartridges to a nearby bore.
        local ammo = { ["9x19_Bullet"]="9mm", ["45_Bullet"]="45ACP",
            ["357_Bullet"]="357", ["44_Bullet"]="44", ["3030_Bullet"]="3030",
            ["308_Bullet"]="308", ["762x51_Bullet"]="308", ["223_Bullet"]="556",
            ["556x45_Bullet"]="556", ["12Gauge_Shell_Buckshot"]="12Gauge", ["12Gauge_Shell_Slug"]="12Gauge" }
        for _, module in ipairs({"SWMG", "MarzGuns"}) do
            for name, caliber in pairs(ammo) do
                local key = module .. "." .. name
                if not api.ammoOverrides[key:lower():gsub("[^%w]", "")] then
                    api.registerAmmo(key, caliber, "GoMAttachmentWorkbench")
                end
            end
        end
        registeredSimple = api
    end
    return api
end

function T.owner(part)
    local id = part and part.getModID and part:getModID()
    if (id == "ImprovisedSilencers" or id == "SimpleSuppressors")
        and getActivatedMods():contains(id) then return id end
end

function T.compatible(part, weapon)
    if T.owner(part) ~= "SimpleSuppressors" then return true end
    -- MountOn is deliberately broad upstream; caliber/sandbox checks are not.
    return simpleCompatibility().canAttach(nil, weapon, part) == true
end

function T.canAttach(part, player, weapon)
    if T.owner(part) == "SimpleSuppressors" then
        return simpleCompatibility().canAttachDynamic(player, weapon, part) == true
    end
    return part:canAttach(player, weapon)
end

function T.tools(part, removing)
    local owner = T.owner(part)
    if owner == "SimpleSuppressors" then
        return removing and {{ItemTag.SCREWDRIVER}} or {}
    elseif owner == "ImprovisedSilencers" then
        return part:getFullType() == "Base.PotatoSilencer" and {} or {{ItemTag.SCREWDRIVER}}
    end
end

function T.action(player, weapon, part, removing)
    if T.owner(part) == "SimpleSuppressors" then
        require "simple-suppressors/suppressoractions"
        if removing then return ISRemoveSuppressor:new(player, weapon, part:getPartType()) end
        return ISAttachSuppressor:new(player, weapon, part)
    end
    -- Preserve ISIL's sound, durability, network and weapon-state hooks.
    require "ISIL_SilencerStats"
    if removing then return ISRemoveWeaponUpgrade:new(player, weapon, part:getPartType()) end
    return ISUpgradeWeapon:new(player, weapon, part)
end

return T
