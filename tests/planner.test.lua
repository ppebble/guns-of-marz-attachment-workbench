local P = require "GMAW/Planner"
local function entry(slot, any, consume)
    return { slot = slot, all = {}, any = any or {}, consume = consume }
end
local catalog = { up = entry("RailUp"), down = entry("RailDown"), left = entry("RailLeft"), right = entry("RailRight"),
    scope = entry("Scope", { up = true }), light = entry("Light", { left = true }),
    laser = entry("Laser", { right = true }), grip = entry("Grip", { down = true }),
    other = entry("Scope", { up = true }) }
local available = {}
local id = 0
for name in pairs(catalog) do id = id + 1; available[name] = { { item = item(name, id), key = "player" } } end
local p = assert(P.solve(catalog, {}, available, { "scope", "light", "laser", "grip" }))
assert(#p == 8, "M4 requires all four rails")
local seen = {}
for _, s in ipairs(p) do
    for parent in pairs(catalog[s.fullType].any) do assert(seen[parent], "dependency first") end
    seen[s.fullType] = true
end
assert(not P.solve(catalog, {}, available, { "scope", "other" }), "same-slot conflict")
local shotgun = { up = catalog.up, scope = catalog.scope }
assert(#assert(P.solve(shotgun, {}, available, { "scope" })) == 2)
assert(not P.solve(shotgun, {}, available, { "light" }), "unsupported side rail")
local old = item("other", 100, "Scope")
p = assert(P.solve(catalog, { Scope = old, RailUp = item("up", 101, "RailUp") }, available, { "scope" }))
assert(#p == 1 and p[1].old == old, "replace retains old object")
local withoutRail = { scope = available.scope }
assert(not P.solve(catalog, {}, withoutRail, { "scope" }), "missing prerequisite")
-- Universal Picatinny source is shared by four outcomes: never allocate one twice.
local common = { { item = item("generic", 200), key = "floor" } }
local rails = { up = common, down = common }
assert(not P.solve(catalog, {}, rails, { "up", "down" }), "no generic rail duplication")
common[2] = { item = item("generic", 201), key = "floor" }
p = assert(P.solve(catalog, {}, rails, { "up", "down" }))
assert(p[1].source.item ~= p[2].source.item)
-- Loose outcome rails and shared kits are both usable. Exact outcomes must
-- win even when their source is farther away than a generic kit.
local M = require "GMAW/Model"
local mixedCatalog = {down=entry("RailDown", nil, "generic"), up=entry("RailUp", nil, "generic")}
local exact = {item=item("down", 210), key="floor", kind="Floor"}
local generic = {item=item("generic", 211), key="player", kind="Player"}
local scan = {byType={down={exact},generic={generic}}}
local mixed = M.availability(mixedCatalog, scan)
assert(#mixed.down == 2 and mixed.down[1] == exact and mixed.down[2] == generic)
assert(#mixed.up == 1 and mixed.up[1] == generic)
p = assert(P.solve(mixedCatalog, {}, mixed, {"down", "up"}))
assert(#p == 2 and p[1].source == exact and p[2].source == generic,
    "use exact direction before spending a kit needed by another direction")
assert(#scan.byType.down == 1 and #scan.byType.generic == 1, "availability must not mutate the scan")
local exactOnly = M.availability(mixedCatalog, {byType={down={exact}}})
assert(#assert(P.solve(mixedCatalog, {}, exactOnly, {"down"})) == 1)
assert(not P.solve(mixedCatalog, {}, exactOnly, {"up"}), "directional rail cannot satisfy another direction")
local unmapped = M.availability({down=entry("RailDown", nil, "down")}, scan)
assert(#unmapped.down == 1, "unmapped part is counted once")
local cycle = { a = entry("A", { b = true }), b = entry("B", { a = true }) }
assert(not P.solve(cycle, {}, { a = available.up, b = available.down }, { "a" }))
local conflict = { a = entry("A"), b = entry("B") }
conflict.a.excludes = { b = true }
assert(not P.solve(conflict, {}, { a = available.up, b = available.down }, { "a", "b" }))
local pistol = { mount = entry("RailUp"), sight = entry("Scope", { mount = true, wrong = true }) }
local selfExclusive = { suppressor = entry("Suppressor"), scope = entry("Scope"), muzzle = entry("Canon") }
selfExclusive.suppressor.excludes = { suppressor = true, muzzle = true }
local sources = { suppressor = available.up, scope = available.scope, muzzle = available.down }
assert(P.solve(selfExclusive, {}, sources, { "suppressor" }), "self-exclusion must not reject installation")
local installedSuppressor = { Suppressor = item("suppressor", 300, "Suppressor") }
assert(P.solve(selfExclusive, installedSuppressor, sources, { "scope" }), "installed self-exclusive part must not block unrelated slots")
assert(not P.solve(selfExclusive, installedSuppressor, sources, { "muzzle" }), "distinct muzzle exclusion remains enforced")
assert(#assert(P.solve(pistol, {}, { mount = available.up, sight = available.scope }, { "sight" })) == 2)
assert(not P.solve(pistol, {}, { sight = available.scope, wrong = available.down }, { "sight" }))
print("planner: dependencies, four rails, shotgun, pistol, replacement, missing, exclusives, cycle, shared quantities")
