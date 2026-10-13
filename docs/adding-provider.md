# Adding an independent attachment provider

Register an integration from one shared Lua startup module on both client and
server. Require `GMAW/Adapters`, register the system, then register its weapon
and part owners. The shared window, scanner, planner and existing native-action
dispatcher need no edits for ordinary new slots. No automatic discovery or
generic action factory is involved.

The supported boundary is native `WeaponPart` items mounted in
`HandWeapon:getWeaponPart(slot)`. A system implemented only in modData, or one
consuming a different generic item to create an outcome, needs separate integration
work. Do not claim support for those systems through these registrations.

## Registration contract

`Adapters.registerProvider(provider)` requires:

- `attachmentSystem`: unique nonempty ID, explicitly shared by the adapters below.
- `slots`: nonempty ordered list of unique native part-type strings. New names are
  appended to the common display order; existing GoM/GGS ordering is preserved.
- `metadata(weapon, part, catalog, context)`: returns `all`, `any`, `excludes`
  FullType-to-true sets for the planner; omitted sets are treated as empty by the
  planner. `consume` should be omitted or equal to the part's FullType for this
  independent native-action route.
- `removable(part, weapon)`: read-only eligibility for opening a removal UI.
  Actual removal must also be enforced by `canDetach` and native actions.

Optional provider callbacks:

- `prepareMetadata(weapon, catalog)`: request-local context for `metadata`.
- `selectable(part)`: exclude internal/stateful parts from the catalog; defaults
  to inclusion for explicitly registered part owners.
- `permanent(part)`: block workbench removal; defaults to false.
- `depends(childFullType, parentFullType, weapon)`: installed dependency relation
  for child-first detach and reverse restoration during parent replacement.
  Defaults to no automatic dependent removal. Do not infer this relation from
  every alternative in `any`; the native system owns its meaning.
- `toolKey(part)`: existing `IGUI_GMAW_` translation suffix, such as `Wrench`.

`registerWeapon(id, spec)` retains the existing exact `owner`, `requires`, optional
`excludes`, and `matches`/`mountOwners` admission contract. Set `attachmentSystem`
explicitly. Its legacy `slots` field only narrows MountOn admission; it is not a
per-weapon capability restriction. Provider slots and native MountOn plus part
compatibility determine candidates.

`registerPart(id, spec)` retains exact owner/activation plus required
`compatible`, `canAttach`, `tools`, `action` callbacks. Add `canDetach` for native
removal restrictions. Optional `canPlanAttach(part, player, weapon)` allows a
preview with a prerequisite still queued; omission uses strict `canAttach`.
Strict `canAttach` and the action's own validation still run at execution time.
Optional part `toolKey(part)` overrides the provider label. Tool-free parts show
NoTools; unspecified independent tool labels use the generic Tools label.

The old omitted attachmentSystem -> GoM default remains solely for compatibility
with earlier adapters. It does not create a new system. A new independent provider
must explicitly use the same system ID in all three registrations.

## Native behavior and activation

Load upstream dependencies lazily after activation, especially inside `action`.
The returned native action must support the existing SP queue and server
`isValid()`/`complete()` contract. Native code owns refunds, inventory/weapon
synchronization and item state; this registry does not implement them.

Parent replacement is only supported when native checks permit safe preflight
and later ordered removal/restoration. Otherwise refuse it and require users to
remove children first, as GGS does. Never weaken native safety checks to force a
plan through. Stateful/irreversible parts can be excluded with `selectable`.

GGS's global action replacement still blocks all non-GGS mutations. GoM's native
prerequisite/exclusion checks remain in the unchanged action/server paths. Verify
coexistence explicitly or use adapter `excludes` to reject untested combinations.

Register during startup, before user interaction, and treat registrations as
immutable. Registration invalidates the catalog cache to tolerate startup load
ordering. This is not runtime mod hot-loading. Slots use
`IGUI_GMAW_Slot_<slot>` translations supplied by the integration. New slots get
generic card placement and no connecting lines without a verified visual profile.

## B: another weapon owner sharing A's parts

Only add a weapon adapter with A's attachmentSystem, both required mod IDs and
A's part owner in `mountOwners`. Native MountOn must name B's firearms. Do not
register B's own parts unless it has an explicit native integration. Each weapon
still uses a single attachment system; multiple systems on one gun are out of scope.

## Executable example and verification

`tests/provider-extension.test.lua` is the executable synthetic A/B example. It
registers TestMount/TestOptic slots, parent metadata, native validation and actions;
exercises the common UI data and unchanged authority; and rejects foreign owners,
forged slots, missing dependencies and invalid native actions. Run
`scripts/test.ps1` for this and existing GoM/GGS/Emre regressions.

Test doubles demonstrate the integration contract, not a real new mod's gameplay,
packet synchronization or arbitrary native compatibility. Verify those against the
chosen mod in SP and MP before advertising support.
