# Verification status

## Source tests — automated

Run `scripts/test.ps1`:
- Actual Kahlua compiler and execution of mod source with engine/UI mocks.
- Dependency planning, quantities, exclusives, source access, slot cards and icon draw calls.
- Read-only preflight tool checks and child-before-parent removal ordering.
- Native-action dispatch: zero item mutation on enqueue; all transfers before assembly; generic rail outcomes; dependency-first installs; duplicate start/stale cart rejection.
- Cancellation after a simulated native transfer retains the moved item and does not assemble remaining parts.
- Static contracts prohibit direct client inventory/attachment mutations and require the narrow server authority handler.
- Actual game JSON translation reader loads **60 EN + 60 KO keys**.

Mocks do not prove native Java inventory replication or visible character motion.

## Installed definitions — automated read-only

Run `scripts/test-installed.ps1`:
- Current local GoM: **440 item definitions / 42 script-file SHA-256 hashes**.
- M4A1, Mossberg 590, Benelli M4, M92FS, M1911 and DEAGLE.
- Actual installed Gunworks dependency, exclusivity and universal attachment modules plus GoM registrations run inside Kahlua.
- Actual GoM screwdriver / wrench / pipe-wrench callback, including broken-tool rejection.
- Actual installed vanilla ISUpgradeWeapon/ISRemoveWeaponUpgrade plus Gunworks hooks execute against mock inventories: normal duration 50, construction does not mutate, completion consumes generic rail, removal returns generic rail.
- Evidence generated under `evidence/installed-definitions.json`; no copied upstream code in release contents.

## Local installation — separate evidence

`scripts/install-local.ps1` generates `evidence/local-install.json` with destination and source-matching file hashes. This proves deployed files only. It does not enable the mod in a preset or prove the game loaded it.

## In-game — NOT VERIFIED

No fresh world, full restart, screenshot, client/server session or Steam publication evidence has been collected. Do not publish or label this build fully verified yet.

- [ ] Fresh single-player: GoM + Gunworks + workbench only; open window without Lua errors.
- [ ] Korean and English revised icon/card layout, tooltip wrapping, supported slots, small resolution.
- [ ] Player/floor/furniture/vehicle quantities and blocked wall/locked storage.
- [ ] M4A1: four generic rails plus dependent accessories, no double consumption.
- [ ] Mossberg/Benelli: upper rail supported, unsupported side-rail cards omitted.
- [ ] M92FS/M1911/DEAGLE: correct mount and muzzle options.
- [ ] Vanilla firearm under GoM; legacy/other mod excluded.
- [ ] Replaced scope and parent rail return correctly; stats and child attachments retained.
- [ ] Full client restart and save reload: attachment and inventory state retained.
- [ ] Host + separate client: nearby weapon ownership and floor/vehicle replication.
- [ ] Second player removes a chosen part: pre-start cart rejected; mid-work remaining actions stop without undoing completed operations.
- [ ] Two competing applies, closing/reopening pending window, split-screen response isolation.
- [ ] Dedicated server: safehouse, locked containers, authoritative inventory, reconnect consistency.

Known bounded omission: active/stateful underbarrel removal/replacement remains fail-closed. The previous custom publication/rollback path no longer exists. Test native cancellation, tool equipping, assembly motion and host/client synchronization after a full restart.

## Latest follow-up verification (2026-09-08)

- Source: scripts/test.ps1 PASS, including no-window tick progression, close preservation, minus/double-click, railing child-first removal, native cancellation, delayed result and missing-result failure.
- Installed-source: scripts/test-installed.ps1 PASS (440 definitions, 42 upstream file hashes, 6 target weapons; native timed-action completion and universal refunds under mocks).
- UI: draw/callback tests only; no fresh rendered screenshot. The visual-verdict skill is not installed.
- Runtime: a dedicated server authority path now logs `[GMAW] server applied` or `[GMAW] server rejected` for each completed operation. New in-game verification remains required, including multiplayer and game restart.

## Split compatibility browser (2026-09-09)

- `scripts/test.ps1` passes after the right column split: both columns have approximately equal width; a rail is pinned in the mount list while scope options remain in the selected-slot list. Native JSON translation-reader validation loads 61 matching EN/KO keys.
- Installed-game visual validation remains pending; no screenshot or gameplay process was used by this source test.

## Tool readiness strip (2026-09-09)

- Source tests cover an accessible nearby screwdriver, broken nearby wrench, native transfer of a nearby required tool before weapon parts, and no tool-status text. The screwdriver is enabled; the broken wrench is treated as unavailable and gets the red disabled border. Translation reader loads matching 61-key EN/KO files.
- Runtime render verification is pending; actual icon textures and player inventory behavior require an in-game run.

## Nearby-tool selection and list clipping (2026-09-09)

- Source tests prove an otherwise tool-gated compatible part remains selectable when a working required tool is in an accessible nearby container; the existing action test proves that tool transfers before parts.
- Source UI test verifies an offscreen cart row produces no draw calls, preventing it from painting above its scrolling viewport.
- In-game visual verification remains pending.
