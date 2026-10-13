local G = {attachmentSystem="gom"}
G.slots = {"Scope", "LaserRifle", "LightRifle", "Foregrip", "Bipod", "Underbarrel",
    "Canon", "Suppressor", "Barrel", "Shellholder", "Stock", "Sling", "RecoilPad", "RailUp",
    "RailDown", "RailLeft", "RailRight", "CanonMount"}
local Framework = require "GMAW/Framework"
G.enabled = Framework.enabled
function G.owned(item)
    local id = item:getModID()
    return id == "GunsOfMarz" or id == "MarzGuns" or id == "pz-vanilla"
end

-- Simple Suppressors re-declares these vanilla scripts for render mappings,
-- changing their reported owner. Do not admit arbitrary Base/addon firearms.
local simpleVanilla = {
    ["Base.Shotgun"]=true, ["Base.JS3T_Shotgun"]=true,
    ["Base.AssaultRifle"]=true, ["Base.VarmintRifle"]=true, ["Base.JS14_Rifle"]=true,
    ["Base.Pistol"]=true, ["Base.Pistol2"]=true, ["Base.Pistol3"]=true,
    ["Base.TrapperCarbine"]=true, ["Base.L92_Carbine"]=true, ["Base.L94_Rifle"]=true,
    ["Base.AssaultRifle2"]=true, ["Base.HuntingRifle"]=true, ["Base.MSR7T_Rifle"]=true,
}

-- Keep existing GoM / vanilla admission separate from opt-in adapters.
function G.coreSupported(item)
    return G.enabled() and (G.owned(item) or (item:getModID() == "SimpleSuppressors"
        and getActivatedMods():contains("SimpleSuppressors") and simpleVanilla[item:getFullType()] == true))
end

function G.toolGroups(slot)
    -- The shipped Old Version uses ItemCodeOnTest.hasScrewdriver, not the
    -- current GoM slot-specific wrench / screwdriver callback.
    if getActivatedMods():contains("MarzGuns") then return {{ItemTag.SCREWDRIVER}} end
    if slot == "Foregrip" then return {} end
    if slot == "CanonMount" or slot == "Canon" then
        return {{ItemTag.WRENCH, ItemTag.PIPE_WRENCH}}
    end
    if slot == "Barrel" then
        return {{ItemTag.SCREWDRIVER}, {ItemTag.WRENCH, ItemTag.PIPE_WRENCH}}
    end
    local screwdriverSlots = {Scope=true, RailUp=true, RailDown=true, RailRight=true,
        RailLeft=true, Bipod=true, Shellholder=true, Stock=true, Underbarrel=true,
        Sling=true, LaserRifle=true, LightRifle=true}
    return screwdriverSlots[slot] and {{ItemTag.SCREWDRIVER}} or {}
end
function G.toolKey(part)
    if part:getModID() == "MarzGuns" then return "Screwdriver" end
    if part:getModID() ~= "GunsOfMarz" then return "Tools" end
    local slot = part:getPartType()
    if slot == "Barrel" then return "BothTools" end
    if slot == "Canon" or slot == "CanonMount" then return "Wrench" end
    if slot == "Foregrip" then return "NoTools" end
    return "Screwdriver"
end

function G.removable(part, weapon)
    local fullType = part:getFullType()
    return not Framework.Permanent.IsPermanent(fullType)
        and not Framework.Underbarrel.UnderbarrelAttachments[fullType]
        and not Framework.Required.IsRemovalBlocked(weapon, fullType)
end

function G.permanent(part)
    return Framework.Permanent.IsPermanent(part:getFullType())
end

function G.selectable(part) return not G.permanent(part) end

function G.depends(child, parent)
    if Framework.Required.RequiresParent(child, parent) then return true end
    for _, fullType in ipairs(Framework.Railing.AcceptedAccessories[parent] or {}) do
        if fullType == child then return true end
    end
    return false
end

function G.metadata(weapon, part)
    local fullType = part:getFullType()
    return {all=Framework.Required.Dependencies[fullType] or {},
        any=Framework.Required.AnyDependencies[fullType] or {},
        excludes=Framework.Exclusives.Exclusives[fullType] or {},
        consume=Framework.Universal.GetGenericItemTypeForOutcome(weapon, fullType) or fullType}
end

function G.register(adapters)
local slots = {}
for _, slot in ipairs(G.slots) do slots[slot] = true end
-- First optional integration: GoM's own native MountOn registrations are the
-- compatibility authority. No Emre weapon IDs or parts are redefined here.
adapters.registerWeapon("emre-gom", {
    owner = "EmreFirearmsPack_B42", attachmentSystem=G.attachmentSystem, slots=slots,
    requires = {"GunsOfMarz", "EmreFirearmsPack_B42", "EmreFPGoMCompat"},
    excludes = {"MarzGuns"},
    mountOwners = {GunsOfMarz = true, MarzGuns = true},
})

end

return G
