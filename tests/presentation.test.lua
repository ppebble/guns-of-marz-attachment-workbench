local V = require "GMAW/Presentation"
local function part(name, id, slot)
    local p = item(name, id, slot)
    p.getName = function() return name end
    return p
end
local rail, scope, absent = part("rail", 1, "RailUp"), part("scope", 2, "Scope"), part("absent", 3, "Scope")
local cat = { rail = {slot="RailUp",part=rail,all={},any={}},
    scope = {slot="Scope",part=scope,all={},any={rail=true}},
    absent = {slot="Scope",part=absent,all={},any={rail=true}} }
local available = { rail={{item=rail,key="player"}},scope={{item=scope,key="floor"}},absent={} }
local view = V.build(cat, {}, available, {}, {}, {})
assert(#view.slots == 2 and view.slots[1].slot == "Scope" and view.slots[2].slot == "RailUp",
    "attachment cards precede prerequisite rails")
assert(view.slots[1].installed == nil, "empty cards must not show a fake installed part")
assert(view.bySlot.Scope.options[1].fullType == "scope", "available choices precede missing choices")
assert(not view.bySlot.Scope.options[1].dim and view.bySlot.Scope.options[1].quantity == 1)
assert(view.bySlot.Scope.options[2].dim and view.bySlot.Scope.options[2].quantity == 0)
view = V.build(cat, {}, available, {Scope="scope"}, {}, {})
assert(#view.plan == 2 and view.bySlot.RailUp.queued == rail and view.bySlot.RailUp.automatic)
assert(view.bySlot.Scope.queued == scope and not view.bySlot.Scope.automatic)
assert(view.bySlot.Scope.installed == nil, "queued is not installed")
view = V.build(cat, {Scope=absent}, available, {Scope="scope"}, {}, {})
assert(view.bySlot.Scope.installed == absent and view.bySlot.Scope.queued == scope)
local current
for _, option in ipairs(view.bySlot.Scope.options) do if option.current then current=option end end
assert(current and current.item == absent and not current.dim, "installed choice can clear replacement even without spare")
scope.canAttach = function() return false end
view = V.build(cat, {}, available, {}, {}, {})
assert(view.bySlot.Scope.options[1].dim and view.bySlot.Scope.options[1].reason == "Tools")
assert(#V.build({}, {}, {}, {}, {}, {}).slots == 0)

-- A nearby valid tool makes an otherwise tool-gated option selectable; the
-- native transfer scheduler moves it before the final canAttach validation.
ItemTag={SCREWDRIVER="screwdriver"}
local screwdriver=item("screwdriver", 77, "Tool")
screwdriver.hasTag=function(_, tag) return tag==ItemTag.SCREWDRIVER end
scope.canAttach=function() return false end
local nearbyScan={entries={{item=screwdriver,key="2:object",kind="Furniture"}}}
view=V.build(cat, {}, available, {}, {}, {}, nearbyScan)
assert(not view.bySlot.Scope.options[1].dim and not view.bySlot.Scope.options[1].reason,
    "nearby required tool keeps a compatible option selectable")
