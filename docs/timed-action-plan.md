# Native timed-action revision

The user supersedes instant atomic mutation with the normal inventory-transfer and weapon-upgrade workflow.

1. Keep compatibility/cart planning and read-only preflight. Remove custom instant mutation and its network endpoint.
2. Revalidate the selected cart, then queue native inventory transfers for the gun and parts. Tools remain required in player inventory.
3. Dispatch native removal and upgrade actions lazily, after prior actions complete; equip parts/tools using the existing GoM context handlers. Generic rails use the Gunworks outcome argument on ISUpgradeWeapon.
4. Use native server-authoritative timed-action processing, never client-side attach/detach or manual inventory increments.
5. Cancellation/races stop remaining actions; completed transfers and upgrades persist like vanilla, not atomic rollback.
6. Regression tests: zero mutation on enqueue, transfer-first order, native action dispatch, generic outcomes, stale cart rejection, pending protection, partial cancellation.

## Follow-up: close persistence, detach, and incomplete installation

- Replace dispatcher timed actions with an OnTick-owned runner. Window close never changes active work. Observe native perform/stop/forceCancel on owned action instances; do not patch global classes or replay cancelled actions.
- Advance only after all issued native actions finish and the actual inventory/weapon result exists. Allow up to 300 ticks for delayed synchronization; fail visibly rather than issue dependent actions against stale state. Log operation identity and terminal outcome.
- Minus and installed-card double-click launch native removal, with required and railing descendants removed first. Explicit removal never reinstalls children. Permanent/stateful underbarrel guards remain.
- Tests cover no-window progression, close retaining active state, both removal gestures, child-first removal, late synchronization, missing mutation, and cancellation without restart.
- Runtime cause remains unconfirmed: the current console contains no workbench exception. This revision removes the intermediate dispatcher and adds diagnostic evidence; an in-game success claim requires a new run.
