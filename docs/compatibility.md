# Compatibility scope

## Guns of Marz Old Version

Supported source target: Workshop 3722134990, `mods/GunsOfMarzPreviousVersion/42.16`, mod ID `MarzGuns`, with the installed Gunworks Framework. Game minimum remains B42.20.4; this is not B41 support or a promise for every historical GoM release.

- Enable exactly one of `GunsOfMarz` / `MarzGuns`. Both or neither disables the workbench.
- Manifest requires `SWMG`, avoiding a mandatory current GoM dependency that prevents old-only activation. GoM is still required by the runtime gate.
- Old Version defines `ItemCodeOnTest.hasScrewdriver` for its attachment checks. It does not ship current GoM's `RequiredToolVisualEquipt` or `MarzGuns_AttachAndDetach` helper. Old-mode planning uses a screwdriver and generic-rail actions select a working screwdriver directly.
- Old Version's animation-sync hook drops both native completion return values. Load it before the workbench Boolean repair. Preserve side effects and explicit return values; normalize nil to true. Native validation is still retained; this does not establish multiplayer success.
- Candidate parts, dependencies, exclusions and generic rails continue to come from loaded definitions / Gunworks registries. No upstream assets or source are bundled.

Verification: `scripts/test.ps1`, `scripts/test-installed.ps1`, and `scripts/test-installed.ps1 -Legacy`. The installed-data harness reads each version's actual registries and six weapon definitions and exercises native generic-rail install/remove with mocked engine objects. It is not in-game evidence. A full restart and fresh old-version client/server operation remain required for live validation.

## Optional Emre Firearms Pack x GoM (source-gated, pending in-game verification)

- Original firearm pack: https://steamcommunity.com/sharedfiles/filedetails/?id=3799972370, mod ID `EmreFirearmsPack_B42`.
- GoM bridge: https://steamcommunity.com/sharedfiles/filedetails/?id=3805214250, mod ID `EmreFPGoMCompat`.
- Only when **both** Emre mods plus **current** `GunsOfMarz` are enabled, accept ranged `HandWeapon` items owned by `EmreFirearmsPack_B42` that also have a GoM-owned, workbench-supported weapon part explicitly listed in runtime `MountOn`. A missing/disabled bridge, GoM Old Version, conflicting GoM versions or unmapped additional Emre firearms cannot pass the adapter. Foreign firearm and part owners remain excluded by default.
- `require=SWMG` remains unchanged; Emre entries are optional `loadModAfter` hints, not dependencies. No changes to sandbox defaults, existing GoM/vanilla weapon admission, or current optional suppressor integrations.
- Keep `M.owned` and the original GoM/Gunworks part catalog unchanged. `GMAW/Adapters.lua` registers exact owners, active-mod constraints and source-of-truth `MountOn` capability, while `M.supported` and `Authority.apply` use the same shared adapter decision. The server also verifies that submitted parts exist in the native candidate catalog for opted-in firearms. No copied Emre item definitions, invented attachment compatibility, magazine/caliber logic, or patches to upstream scripts.
- Current Emre Firearms Pack v0.12.0 contains 49 firearms, while EmreFPGoMCompat v1.0 registers the older 23-gun bridge list. Four entries have no supported GoM attachments (Remington 700, SKS, M1 Garand, Winchester double barrel) and are deliberately not made into empty workbench choices; other unmapped firearms are denied. The bridge author documents **no 3D rendering for added attachments** on Emre models.
- `tests/emre-compatibility.test.lua` verifies the activation matrix, native registration prerequisite, owner isolation, catalog candidates, server refusal and a future non-GoM test adapter with synthetic items. Both Emre Workshop mods are now installed locally. The `emre-test` log confirms 23 Emre guns, 51 of 194 GoM part scripts extended and the patch loaded before the workbench. This is startup/source evidence, **not a complete SP/MP attachment operation proof**.

## Optional suppressors

References: https://steamcommunity.com/sharedfiles/filedetails/?id=3782565181 and https://steamcommunity.com/sharedfiles/filedetails/?id=3779164273

The author lists GoM compatibility and an optional GoM patch for mounted models / extended calibers. The installed `SimpleSuppressors` mod defines `PartType = Suppressor`, uses `SimpleSuppressorsCompatibility.canAttach`, and populates MountOn dynamically in `shared/simple-suppressors/compatibility.lua`.

`GMAW/Attachments.lua` accepts only active `SimpleSuppressors` / `ImprovisedSilencers` part owners. It does not broaden firearm ownership. Neither addon becomes a required dependency.

- Improvised Silencers: five Canon-slot parts; use the owner's runtime MountOn patches (including shotgun restrictions). Standard silencers use a screwdriver; PotatoSilencer uses no tools. SP and MP retain the installed ISUpgradeWeapon / ISRemoveWeaponUpgrade completion chain, including ISIL's sound, durability, network and weapon-state callbacks.
- Simple Suppressors: sixteen base parts in the localized Suppressor slot. Its dynamic compatibility callback decides caliber/sandbox/weapon exclusions, including when the broad native MountOn list is missing a firearm. Register only verified SWMG/MarzGuns ammo item keys for supported bore families; preserve existing overrides. No invented matching of unsupported calibers. SP uses ISAttachSuppressor / ISRemoveSuppressor; MP validates on the server and invokes the same native completion code. Installation is tool-free; removal retains the owner's screwdriver checks.
- Native completion already emits inventory notifications; the workbench server must not send duplicate add/remove messages. Gunworks dependency/exclusive and stale/occupied-slot checks remain in force before mutation.
- Slots stay as defined by the owners (Canon versus Suppressor). No new cross-mod balancing, visual mount patch or global replacement of attachment menus is introduced.

`scripts/test-attachments.ps1` and `-Legacy` extract 21 actual installed part definitions and load the installed GoM compatibility, caliber and timed-action Lua. Coverage includes catalog/view selection, wrong-caliber and sandbox rejection, optional-mod absence, part-only ownership, tool rules, SP action completion, server-authority install/remove and ISIL hook dispatch. Engine objects and sound/condition math are mocked; fresh game screenshots, suppression sound, durability/heat rendering and live multiplayer remain unverified. Optional upstream GoM model/extended-caliber patches are not bundled or required by the workbench; visual coverage remains the owner's responsibility.

## SP / MP verification layers

- `tests/mp-client.test.lua` exercises the client timed action, command emission, delayed server mutation, replicated-state wait and removal. Transport is mocked; client-side item mutation is forbidden by the fixture.
- The client authority action intentionally has no `complete()` method. The installed B42.20.4 `LuaTimedActionNew` constructor sets `useCustomRemoteTimedActionSync` when that method is absent; only `perform()` sends the workbench command.
- `scripts/run-server-smoke.ps1` (and `-Legacy`) boots the actual B42.20.4 dedicated server in a fresh, private non-Steam cache. The private probe uses real Java firearm/part/player objects to check both addon install/remove paths through Authority, plus catalog count and caliber filtering. No mocks replace addon completion/effect methods in this runtime probe. The player is not connected over the network: this does not prove remote-client replication, latency, rendered UI or firing behavior.
- These test caches are ignored, never staged and never share an existing save. Use real copied mod files, not junctions: the attempted junction setup produced null path/checksum and worldgen failures. The runner closes its own server after the probe. Engine map/worldgen warnings are recorded separately from the probe result.
- Duplicate local candidates: the stale `Zomboid/Workshop/GoMAttachmentWorkbench` copy was found to differ from the current local source and moved intact to `Zomboid/mod-backups/GoMAttachmentWorkbench-stale-workshop-20261011-005746`. The only active test copy should be `Zomboid/mods/GoMAttachmentWorkbench`. The genuine Steam Workshop cache is untouched; this is not a Steam upload.
