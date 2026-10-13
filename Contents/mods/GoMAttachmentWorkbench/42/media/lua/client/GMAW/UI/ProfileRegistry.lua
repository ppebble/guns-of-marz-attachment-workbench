-- Rendering preferences are keyed by weapon owner, NOT attachmentSystem.
-- Emre uses GoM native attachment rules but has its own model geometry.
local R = {}
local GoM = require "GMAW/UI/Profiles/GoM"
local Gael = require "GMAW/UI/Profiles/Gael"

function R.forWeapon(weapon)
    local owner=weapon and weapon.getModID and weapon:getModID()
    if owner=="GaelGunStore_B42" then return Gael end
    if owner=="GunsOfMarz" or owner=="MarzGuns" or owner=="pz-vanilla" then return GoM end
    -- In particular EmreFirearmsPack_B42 intentionally does not inherit GoM's
    -- visual anchors, even when its weapon routes to the gom action system.
    return nil
end

return R
