# Current implementation decisions

## Native assembly workflow (2026-09-08)

The newest user instruction supersedes instant atomic batches. Apply is now **Start assembly**:

1. Re-scan and validate the cart signature, weapon state and tools before enqueueing.
2. Queue normal `ISInventoryTransferUtil` actions for the gun and selected parts (no time override). Floor sources use the vanilla loot-page floor view.
3. Lazily dispatch removals child-first, installations dependency-first, then reattach retained children. Lazy dispatch allows native validity checks to see the results of the previous operation.
4. Ordinary parts call the existing GoM `onUpgradeWeapon` / `onRemoveUpgradeWeapon` context handlers, including tool equipping. Universal rails equip their source/tool and use `ISUpgradeWeapon:new(..., outcomeFullType)` as Gunworks does.
5. The normal B42 server timed-action machinery owns completion, inventories, callbacks, stats and synchronization. The custom `GMAW/apply` server endpoint and direct mutation/rollback functions are removed.
6. Native cancellation/races stop remaining work. Completed transfers, removals and installs remain; no whole-cart rollback claim is made. Read-only `Batch.preflight` remains only for planning validation and detach ordering.
7. Owned action instances observe perform/stop/forceCancel without changing native completion. No global native class overrides, no forced instant duration, no client item mutation, no new dependencies. Active/stateful underbarrel removal remains conservatively excluded.

## UI and compatibility

- Three columns: native weapon icons; supported slot cards with actual installed icon and distinct queued preview; selected-slot options (missing compatible parts grey). Current instruction supersedes the old all-slots/X design.
- Translation files use B42 `Translate/LANG/IG_UI.json`. Native JSON-reader tests load 60 keys in EN and KO; no hard-coded English fallback.
- Only current GoM and vanilla definitions under enabled GoM are allowed; legacy and other mod owners are excluded.
- Compatibility intersects explicit MountOn with loaded ModelWeaponPart script declarations. B42 fields have no non-debug Lua accessor, so normal mode reads `getScriptItem():getScriptLines()` without reflection.
- Runtime RequiredAttachment all/any dependencies, UpgradeExclusives, PermanentAttachments and UniversalAttachment registries remain the source of truth. Generic rails reserve one physical source object per outcome.
- Same-Z 3x3 reachable sources, locks/safehouse/vehicle access checks, recursion limit eight. Tools must already be in player inventory.
- Scans happen only on open/refresh/start/transfer dispatch, not every frame. A global OnTick runner checks native action lifecycle and resulting item state; UI polling only consumes the terminal result. Closing the UI has no execution side effects.

## Evidence boundaries

Source mock tests and read-only execution of installed native Lua prove scheduling/contracts, not in-game animation or multiplayer replication. No fresh runtime proof is claimed. See verification.md.

Installed slot cards expose minus and double-click removal. Required and Railing registry descendants are removed child-first; explicit removal does not reinstall them.

## Split compatibility browser

The attachment-slot cards put sights, tactical laser/light, foregrip, bipod, underbarrel, muzzle device, barrel, stock and other direct attachments first; rails and muzzle mounts are at the bottom. The right side is split into equal columns. **Required rails / mounts** stays pinned on the left and includes every rail, muzzle mount, and any candidate that is a registered all/any dependency of another candidate. The selected slot's non-mount attachments remain in the right column. Both columns preserve inventory-first ordering, unavailable grey presentation, tool/dependency tooltip, queue state, and the same assembly planner; the split changes navigation only.

## Tool readiness strip

A compact text-free strip below the compatibility lists displays screwdriver and wrench/pipe-wrench readiness using the actual working item texture. It uses the same accessible 3x3 same-Z scan as parts: player inventory, floor, accessible furniture, and accessible vehicle containers. A missing or broken tool is disabled with a red border; the check refreshes on open and periodically while the window remains open. Before assembly/removal, a required nearby tool is transferred through the native inventory action before its native GoM action runs. Compatibility cards apply the same nearby-tool availability, so they are selectable rather than incorrectly greyed before the transfer.

Custom item/slot draw callbacks replicate the engine list's viewport clipping. This prevents scrolled cart rows from being painted over the status/tool strip.
