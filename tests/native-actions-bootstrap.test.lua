ISBaseTimedAction = {}
function ISBaseTimedAction:derive()
    local c={};setmetatable(c,{__index=self}); c.__index=c;return c
end
function ISBaseTimedAction.new(class,character)
    return setmetatable({character=character},{__index=class})
end
modules["TimedActions/ISBaseTimedAction"]=ISBaseTimedAction
modules["WeaponSystems/Utils/Underbarrel"].HandleAttachmentRemoval=function() end
function syncHandWeaponFields() end
function sendRemoveItemFromContainer() end
function sendAddItemToContainer() end
