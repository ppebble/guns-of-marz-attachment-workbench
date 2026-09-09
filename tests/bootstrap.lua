modules = {}
function require(name) assert(modules[name], "missing module " .. name); return modules[name] end
local required = { Dependencies = {}, AnyDependencies = {} }
function required.RequiresParent(child, parent)
    return (required.Dependencies[child] or {})[parent] or (required.AnyDependencies[child] or {})[parent]
end
modules["WeaponSystems/Utils/RequiredAttachment"] = required
modules["WeaponSystems/Utils/Railing"] = {AcceptedAccessories={}}
modules["WeaponSystems/Utils/PreventRemovals"] = { IsPermanent = function() return false end }
modules["WeaponSystems/Utils/UniversalAttachment"] = { GetGenericItemTypeForOutcome = function() return nil end }
modules["WeaponSystems/Utils/UpgradeExclusives"] = { Exclusives = {} }
modules["WeaponSystems/Utils/Underbarrel"] = { IsWeaponInUnderbarrelMode = function() return false end, UnderbarrelAttachments = {} }
modules["WeaponSystems/Utils/StatsFactory"] = { ReapplyAllModifiers = function() end }
function item(fullType, id, slot)
    return { getFullType = function() return fullType end, getID = function() return id end,
        getPartType = function() return slot end, isBroken = function() return false end,
        canAttach = function() return true end, canDetach = function() return true end }
end
function javaList(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end
function inventory(values)
    return { values = values, getItems = function(self) return javaList(self.values) end,
        isRemoveItemAllowed = function() return true end,
        AddItem = function(self, it) self.values[#self.values + 1] = it; return it end,
        Remove = function(self, it) for i, value in ipairs(self.values) do if value == it then table.remove(self.values, i); return end end end }
end
function instanceof(obj, name) return obj and obj.class == name end
function isClient() return false end
function isServer() return false end
Events = { OnKeyStartPressed={Add=function(callback) gmawCancelKey=callback end}, OnTick = {Add=function(callback) gmawTick=callback end}, OnClientCommand = { Add = function(callback) gmawServerCommand=callback end } }
