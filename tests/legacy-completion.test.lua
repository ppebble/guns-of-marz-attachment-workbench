assert(ISUpgradeWeapon:complete() == true, "legacy nil completion normalized")
assert(ISRemoveWeaponUpgrade:complete() == false, "explicit failure preserved")
assert(require("GMAW/Actions"), "legacy client loads without current GoM tool module")
