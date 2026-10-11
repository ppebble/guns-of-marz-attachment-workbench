# Verification status

## Attachment-system routing and MP checks — 2026-10-12

Weapon/part adapters now declare an attachment system independently of the firearm owner. Context-menu callbacks and the nearby firearm list use `Model.canOpen`, excluding guns with no eligible candidate/removable supported part. The source matrix exercises GoM, Gael, mapped Emre, missing/legacy bridge combinations and unmapped firearms through the actual registered context callback.

All source, current/legacy installed GoM, current/legacy suppressor integration and installed Gael suites passed. Real dedicated-server Gael validation exposed a missing-tool bypass in upstream callbacks; workbench authority now independently enforces recursive nonbroken tool groups for both installation and removal. Missing/broken installation tools and missing removal tools have regression coverage.

The final isolated Gael runtime passed in `evidence/server-smoke-Gael-20261012-001549/server-console.txt`. It exercised actual Java player/items and Gael native completion for mount/scope install/remove, dependency checks and launcher refusal. Its 24 recorded workbench hashes match the current source. No client was connected; this does not prove UI, remote replication or player gameplay. Manual steps and test profiles are documented in [test-servers.md](test-servers.md).

The final isolated Emre runtime also passed in `evidence/server-smoke-Emre-20261012-001716/server-console.txt`: actual `ENF2.AR15` GoM generic rail installation/removal/refund and forged non-part refusal. Both helper-owned servers exited. The local client/server mod was refreshed with 24 matching files. `gael-test` INI/three sidecars, launcher and desktop shortcut were created; all eight existing b42211002/emre-test profile files retained their hashes. The new manual-test world has not been started. The owned-mod client ZIP is `evidence/GoMAttachmentWorkbench-provider-test-20261012.zip` (24 files verified against source).

## Shared-provider revision — 2026-10-11

The provider refactor adds a fresh Gael-only Kahlua environment that rejects any WeaponSystems/MarzWeapons module request, including requests hidden by `pcall`. Coverage includes no-provider activation, Gael ownership, cross-provider refusal, common UI slots, tools, native installation/removal, server authority and protected launcher state. `scripts/test-gael.ps1 -Installed` additionally reads the locally installed Gael definitions and loads its actual shared dependencies and timed-action patch.

These are source/native-Lua tests using mocked game objects, not a live client/server session. Local installation hashes are a separate evidence layer. No Workshop publication is implied. The existing sections below describe earlier verification and retain their historical counts.

Completed checks for this revision: `test.ps1` (including EN/KO/CN 93 UI keys each), `test-installed.ps1` current and `-Legacy`, `test-attachments.ps1` current and `-Legacy`, and `test-gael.ps1 -Installed`. Gael extraction read 1,012 definitions across 88 hashed script files. Its tests include dependency-first scheduled mount/scope installation and a simulated multiplayer command through server authority using Gael's real native Lua completion. Local installation backed up the previous copy and verified 24 matching files under `C:/Users/ask13/Zomboid/mods/GoMAttachmentWorkbench`. Saves, presets and Steam Workshop files were not changed.

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

## In-game — partially verified

The maintainer reports that server testing was completed on 2026-09-09. No
server log, save, screenshot, or test scenario transcript is stored in this
repository, so this records the completed test without over-claiming a fully
reproducible runtime evidence set. Steam publication remains separate.

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
- [x] Server test completed (maintainer report, 2026-09-09).
- [ ] Dedicated server regression record: safehouse, locked containers, authoritative inventory, reconnect consistency.

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

## Server test (2026-09-09)

- Maintainer-reported server test completed.
- This claim is intentionally narrower than a complete dedicated-server
  regression record: retain any future server log, scenario, or screenshot
  with the release notes if one is needed for troubleshooting.

## Thumbnail-inspired layout (2026-09-29)

- The three-column layout now puts a searchable weapon list on the left, a selected-weapon diagram and full scrolling slot list in the center, and rails/mounts above selected-slot choices on the right. The existing cart and action controls remain below.
- Kahlua UI tests exercise the diagram's slot click, narrow-window fallback, search filtering, installed/queued drawing, part choice, removal, and pending-action guards. Source and installed GoM test suites pass with the current Gunworks helper loaded.
- The local mod and Workshop staging match source hashes. No new gameplay or server mutation code was introduced.
- In-game rendering, mouse geometry, and multiplayer appearance still require a fresh game session; the marketing thumbnail is a visual direction, not a pixel-accurate game screenshot.

## Gael stalls and complete slot display (2026-10-12)

- User confirmed attachment/removal in game but reported pauses when opening, selecting, starting and removing, plus missing central diagram slots.
- Reproduced quadratic Gael metadata discovery: 80 compatible parts caused 6,480 MountOn reads. Request-local indexing reduces that to 160; single-part admission performs one read. No persistent cache of weapon state was added.
- Server admission checks one requested candidate without constructing all preview metadata. Existing live inventory, tools, dependency and native-action checks remain.
- Preview groups candidates by slot, reuses the selected cart plan, and omits native/tool checks for already rejected plans. Mutable inventory/tool regressions pass.
- The center retains the firearm image above every supported slot, including mounts/rails, with bounded row navigation. Geometry tests cover 29 slots, narrow width, enlarged font, distinct hit targets and automatic reveal from the lower list.
- Source suite and installed Gael, GoM current/legacy, and suppressor current/legacy suites pass. Evidence: evidence/perf-source-final.txt, evidence/perf-gael-installed-final.txt and evidence/perf-*.txt.
- These call counts and UI geometry tests do not measure actual frame-time improvement or prove live rendering. User in-game latency and appearance verification remains separate.
- Dedicated engine Gael probe passed in evidence/server-smoke-Gael-20261012-013356; no connected player was used. Local and Workshop-staged copies each match all 24 source files, with previous copies backed up and Workshop metadata preserved.

## Spatial attachment nodes (2026-10-12)

The grid revision is superseded by a large central firearm with asymmetric role-based callouts. The normal layout shows optics, stock, muzzle, laser, grip, light, bipod and top rail together when supported. Cards have independent hit targets and separate orthogonal connector lanes. All supported slots remain in the lower list; selecting an overflow slot promotes its node into available diagram space.

Known square two-handed GoM/Gael inventory art is rotated uniformly toward horizontal. Other art preserves its aspect ratio. Anchors approximate attachment roles, not per-model bones. Existing low-resolution inventory textures limit enlargement quality.

The source UI harness covers normal, narrow and large-font layouts, collision bounds, eight simultaneous main roles, selected overflow and connector separation. The exported geometry drives scripts/render-spatial-preview.ps1; evidence/spatial-layout-preview.png is a source-based preview, not an in-game screenshot. Live visual confirmation remains pending. Deployment is deferred while the user runs an unrelated escape-mod test.
- Spatial UI deployment completed after the user closed the game: local and Workshop-staged copies each match all 24 source files; prior files backed up, Workshop metadata preserved. Evidence: evidence/spatial-deployment.json. No Steam upload or live gameplay verification.

## Stable complete diagram (2026-10-12)

Supersedes the selected-overflow behavior above. All actual attachment slots are laid out on first open, independent of selection; prerequisite rails/mounts map to destination nodes. The installed Gael SVD fixture has 13 raw slots and 12 visible nodes after Mount is merged into Scope. Stock/sling and muzzle/shroud use side space. Narrow layouts compact cards without dropping slots. Owned-only filtering affects candidate choices, not supported slot visibility.

Absolute screen coordinates fix rotated weapon rendering; generated inventory icons use their current dimensions to fit list cells. Source regressions cover window movement, generated textures, stable positions, complete slot coverage, aliases, narrow layouts and large fonts. Full source suite passed in evidence/stable-final-source.txt; installed Gael data checks passed in evidence/stable-gael-installed.txt. The source-based preview evidence/stable-layout-preview.png is not live game evidence.

After game shutdown, local and Workshop-staged copies each matched 24 source files. Backups retained and Workshop metadata preserved; see evidence/local-install.json and evidence/stable-stage-install.json. No upload or connected multiplayer visual test was performed.

## Gael internal visual/state exclusion (2026-10-12)

Read-only audit of installed Gael 3616176188 found 375 WeaponPart definitions. Internal items include Hide_Beam (9), Clip magazine visuals (62), AMMO loaded-projectile visuals (7), four deployed bipod variants and four empty launcher variants. Evidence is native GGS_LaserLightServer.lua, PartAbility/Magazine/ShowMagazine.lua, GGS_ArcheryReload.lua, PartAbility/Stool/GrenadeLauncher_SetFunction.lua, GGS_BipodState.lua and GGS/Underbarrel.lua. Actual magazines are separate inventory items, not Clip WeaponPart upgrades.

Hide_Beam/Clip/AMMO/legacy Ammo are excluded from the workbench catalog and attachment admission. Hide_Beam and Clip no longer appear as displayed slots even while native effects are installed. Exact deployed bipod FullTypes are excluded as separate choices; normal bipods remain and installed state is retained. Existing Stool exclusion includes empty launcher variants. No upstream state or source is modified. Consequently the earlier SVD 12-node count is superseded: its generated Clip node is no longer equipment.

Source and installed Gael tests passed (evidence/beam-source.txt, evidence/beam-installed.txt). Regression first failed at beam candidate admission (evidence/beam-before.txt); tests now cover candidate rejection, preview rejection, forged install/detach rejection, preserving an active beam and catalog membership for every installed real/internal part. Live game verification remains separate.

## Fixed weapon model preview (2026-10-12)

The central diagram now creates a native ISUI3DScene from the selected item's getStaticModel model script. The left weapon list remains unchanged. Selection replaces the scene model; steady frames and slot selection reuse it. Closing the window removes the model and hides/removes the scene. Missing model/API failures use the prior icon fallback. Mouse drag/wheel and native automatic rotation are disabled.

Native AttachmentEditorUI and UI3DScene bytecode establish world attachment + weapon rotation and a UserDefined (90,0,0) camera for muzzle-right, sights-up standard weapon models. Rifle/pistol zoom and origin offsets are conservative initial framing, not verified mesh-bound fitting. Model axes may need exceptions after in-game testing. This first pass renders the weapon body, not separately composed installed attachment meshes.

tests/model-preview.test.lua covers repeated-frame reuse, replacement/release, fixed camera/input, missing-model fallback and retained left-list selection callback. Full suite and installed Gael checks passed (evidence/3d-source.txt, evidence/3d-gael.txt). No actual client rendering, frame time or connected multiplayer visual result is claimed.
