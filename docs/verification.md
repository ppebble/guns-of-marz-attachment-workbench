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

Follow-up: shared automatic estimated framing now derives horizontal/vertical extents from model attachment offsets, applies inverse world attachment rotation/translation and native weapon rotation, then centers and uniformly scales with clearance. It recalculates only on selection or viewport size change. Actual mesh bounds are public Java fields without ordinary Lua getters; this is deliberately an estimate, not exact silhouette fitting. Models with insufficient usable points retain fixed framing. Tests include translated origins, world rotation, width/height fit, resize/reuse, and representative installed Gael SVD, GoM M4A1 and emre M4A1 coordinates. No per-gun overrides or asset redistribution. Source changes remain undeployed while the user tests GoM.

The central diagram now creates a native ISUI3DScene from the selected item's getStaticModel model script. The left weapon list remains unchanged. Selection replaces the scene model; steady frames and slot selection reuse it. Closing the window removes the model and hides/removes the scene. Missing model/API failures use the prior icon fallback. Mouse drag/wheel and native automatic rotation are disabled.

Native AttachmentEditorUI and UI3DScene bytecode establish world attachment + weapon rotation and a UserDefined (90,0,0) camera for muzzle-right, sights-up standard weapon models. Rifle/pistol zoom and origin offsets are conservative initial framing, not verified mesh-bound fitting. Model axes may need exceptions after in-game testing. This first pass renders the weapon body, not separately composed installed attachment meshes.

tests/model-preview.test.lua covers repeated-frame reuse, replacement/release, fixed camera/input, missing-model fallback and retained left-list selection callback. Full suite and installed Gael checks passed (evidence/3d-source.txt, evidence/3d-gael.txt). No actual client rendering, frame time or connected multiplayer visual result is claimed.

Gael live feedback supersedes the initial camera assumption: the original preview faced left. Gael alone now uses (-90,180,0), reversing horizontal direction while preserving vertical orientation, with a matching centering offset. Source suite passed in evidence/3d-gael-facing.txt. After game/server shutdown, local and staged copies matched 24 source files (evidence/3d-facing-install.json). Corrected in-game appearance remains to be checked.

## Held-model orientation correction (2026-10-12)
User screenshots identify Emre M16A1 (internal ENF2_M16A2, world rotation 0/180/90) and GoM M16A2 (world rotation 180/0/180) as broken. Preview now disables native world attachment and conditional weapon hack, applies explicit held-model rotation 0/180/90, and uses one fixed camera across providers. Negative muzzle Y reverses the barrel-axis rotation. Estimated framing uses the same held-model coordinate transform and ignores floor offsets/rotations. Source regression includes both reported definitions, GGS SVD, GoM/emre M4A1, floor-pose independence and opposite barrel direction. Source and installed Gael suites passed in evidence/held-orientation-source.txt and evidence/held-orientation-gael.txt. Actual rendering still needs user validation; game and server running, deployment deferred. Mesh-bound auto fit and exact silhouette centering are not claimed.

Held-model orientation and estimated framing deployed after shutdown check: local and staged copies match 24 source files, backups retained and Workshop metadata preserved. Evidence: evidence/held-frame-install.json. In-game validation remains pending.

## Compact muzzle-right diagram revision (2026-10-12)

The user reported a common muzzle-left orientation for GoM and Emre and long, overlapping leaders across the attachment diagram. The shared fixed camera remains UserDefined (-90,180,0) with world-attachment and weapon-rotation-hack disabled; the held-model barrel rotation changes from +90 to -90 degrees for positive-Y barrels, and direction detection first compares the muzzle with a rear attachment instead of assuming the script origin sits at the stock. The change applies to Gael/GGS, GoM, and Emre through the same path. This is source-level orientation correction, **not a verified in-game rendered result**.

The normal window maximum changes from 1120x820 to 1240x850 (still screen-clamped), with the central column increased to 52% and responsive diagram height keeping room for the scrolling list. Attachment nodes are packed near their physical-role anchors, with minimum spacing, separate short connector paths, and up to four cards per left/right edge when height allows. The former lower crowd of laser/grip/bipod/light now distributes over the four edges; the top row likewise avoids fixed-grid starting positions. Tight screens retain the compact fallback. The model scene is not recreated on slot selection; inventory actions, authority, source adapters, and Workshop payload metadata are unchanged.

Regression contracts cover the user's Emre/GoM seven-slot layout, GGS SVD dense role layout, all-slot synthetic layouts, large fonts/small viewport, hit areas, non-overlap, parent-window reuse, and model direction with offset origins. The GGS source geometry is approximately 624x375 pixels with two top nodes, two bottom nodes, and four on each side (the fixture still includes a generated Clip slot; the actual provider excludes internal Clip). No in-game screenshot or multiplayer-client rendering is inferred from Lua mock tests.

The final scripts/test.ps1 (including installed Gael provider data, translation and contracts) and git diff --check passed. After confirming no active PZ client/dedicated server, only the workbench client Window.lua was backed up and copied into both Zomboid/mods and Zomboid/Workshop/GoMAttachmentWorkbench staging. Both installed copies matched the source SHA-256 CB2B13CBD7300B10ACBACC2B1B92B8A2A77E25ED92D87D67CE3C3DF35C52D0F5. Backups: evidence/backups/ui-diagram-20261012-092402-177/. All other installed files, workshop metadata, saves, server configs, and Steam publication were left unchanged. In-game rendered orientation and diagram appearance still require a fresh game session.

## Static camera and AWP silhouette repair (2026-10-12)

The user's actual screenshot of the Emre AWP shows only its rear stock on the right edge and a camera-rotation animation. Investigation of the installed B42.21 UI3DScene bytecode confirmed two previously missed native behaviors: (1) UI3DScene **initializes as View.Right**, while switching to UserDefined starts a **350 ms camera quaternion transition**; (2) SceneObject local transforms compose as **translation × rotation × scale**, and View.Right projects world Z horizontally and world Y vertically. Earlier fitModelPreview wrote the horizontal offset to world X and used inconsistent geometry assumptions after the model was rotated.

New source keeps the native **Right** view (no view change/animation) and disables object auto-rotation. The held-model pose uses X=-90, Y=0, Z=0 for a positive-Y barrel, or X=-90, Y=0, Z=180 for a negative-Y barrel, preserving sights-up for both. It centers projected X via **object world Z** and projected Y via **object world Y**. Estimated framing includes extra stock, muzzle, grip, and optic margins instead of equating mount offsets with mesh vertices. Emre's installed ENF2_AWP model script has muzzle=(0,0.5781,0.0476), magazine≈(0,0.103473,0.037203) and no stock marker; the regression explicitly covers this two-point model.

The full `scripts/test.ps1` suite, including updated orientation/framing fixtures, passed. A separate compiled reflection-based probe ran against the **installed game's own JOML Matrix4f at Java 25**, exercising the actual native matrix rotation/translation/projection contract: estimated AWP stock at -145.0px and muzzle at +142.8px within a 388px scene, sight at +47.0px and grip at -56.1px within 188px, scale≈1.021. The reversed-Y barrel likewise projects muzzle-right and sights-up. This proves the **tested coordinate transform** but does not inspect the exact mesh bounding box or actual GPU render. The temporary probe is in ignored `.build/PreviewNativeMatrixProbe.java` and did not change game files.

At this time client ProjectZomboid64.exe and dedicated emre-test server are running. This correction is **source-only / not deployed** to local or Workshop-staged mods; no running-session hot replacement, save mutation, workshop publication, or upstream mod edits were made. The prior installed screenshot build remains in place until the client and server are closed and the corrected Window.lua can be backed up and copied safely. Run `scripts/install-preview-fix.ps1` after both exit: it validates exact source/prior hashes, backs up and syncs only the two Window.lua copies and refuses to overwrite mismatched files. The installation guard was exercised with both processes live and correctly refused the hot-swap; existing installed hashes remained unchanged.

## Left-facing preview / horizontally mirrored diagram (2026-10-12)

The user confirmed that the prior static-camera build still draws firearms facing left. Do **not** attempt another unverified model/camera rotation. The native engine's UI3DScene ModelRenderData.initModel calls `ModelInstanceRenderData.postMultiplyMeshTransform()` after constructing the scene-object transform; this applies the transposed `ModelMesh.transform` matrix if supplied. Our earlier standalone JOML projection probe modeled camera × scene-object transform only, **omitting the mesh-level transform**. It therefore could not establish the actual rendered muzzle direction; tests that asserted "right-facing" were insufficient and must not be reported as in-game visual proof. Missing mesh bounds also caused earlier flawed auto-fitting attempts, and the UserDefined view had a native 350ms quaternion transition.

The current source now mirrors **UI geometry only** at the end of cardLayout: `node.x = panel.width - node.x - node.width`, `anchorX = panel.width - anchorX`, and the side leader coordinates `edgeX` and `elbowX`; `side` left/right swaps. Top and bottom cards, clicks, connectors and all existing source/provider slot layouts are mirrored consistently. The 3D camera, rotation, zoom, model loading, outline and renderer are **unchanged** in this revision. The full `scripts/test.ps1` (including real Gael provider fixture coverage) and `git diff --check` passed with mirrored Emre/GoM and GGS geometry expectations.

The game client and a dedicated server were running at verification. The change remains **source-only**, installed local/staged Window.lua hashes are still `46D23531DED00A885057A01B579823890B5C3D919A389D169E4D1B9F81A6E824`, and mirrored source Window.lua SHA-256 is `1C401CF99D9206FAD98FC879FF8729BBB5FFBFD44B361196FA172BA3112582E4`. The guarded `scripts/install-mirrored-diagram.ps1` will back up and sync only those two Window.lua files after both processes exit. It validated against live processes and correctly refused a hot-swap. No upstream mods, saves, server profiles, Workshop metadata or Steam upload were modified.

## Remove misleading endpoints / subdued connector leaders (2026-10-12)

The user accepts the left-facing model and mirrored layout, but notes the leader tips suggest exact attachment points when the source only supplies approximate edges. In Window.lua, removed the 5x5 orange rectangles at n.anchorX/n.anchorY. Selected leader opacity changes to 0.62; unselected to 0.34, with muted unselected RGB. The segment helper suppresses coincident endpoints instead of creating 1x1 dots. Card borders, selected slot labels, hit-testing, model camera/rotation, 3D framing, actual attachment authority, and provider adapters are untouched.

Native model scripts confirm provider-dependent support for attachment locations: GGS SVD lists muzzle, Canon, Handguard, Stock, Mount, Grip, Laser, Light, Scope, etc. with precise model-local offsets and rotations (for example muzzle 0/.6279/.027; Scope 0/.0852/.045). A saved GoM 42.16 M4A1 script defines muzzle, magazine, rail_down (0/.2074/.0083), rail_left, stock_folded, etc. Emre ENF2_AWP supplies muzzle and magazine, but no scope or stock attachment. The workbench's *logical slot* is not universally identical to a ModelScript attachment ID, and model-local coordinates do not directly supply pixel locations: projection must account for the actual model/mesh transform, camera, and scale. Thus no faux `exactAnchors` slot-percentage table or unsupported automatic screen projection was introduced. Exact per-model screen anchors should be a separate feature with verified provider-specific alias mapping, rendering projection, and fallback omitting leaders for missing attachments.

Source regression now asserts no orange 5x5 anchor markers, no zero-length 1x1 segment dots, dim nonselected leader alpha and highlighted selected leader alpha. Full scripts/test.ps1 and installed Gael fixtures passed. The client/server were running, so source changes have not been installed, no live Lua hot-swap was attempted, and there is no claimed in-game rendering proof for the revised connector styling.

## Subtle leader installation and UI modularity audit (2026-10-12)

After verifying the client and server had both stopped, scripts/install-subtle-leaders.ps1 backed up and copied only Window.lua into Zomboid/mods/GoMAttachmentWorkbench and the local Workshop staging tree. Both installed copies and source match SHA-256 68BD2FD81977A65CB83187D0D39CF2342D4ADA1A72AD81C1B83C144DD0E28C2E. Backups: evidence/backups/subtle-leaders-20261012-210047-303/. The entire scripts/test.ps1 suite, including installed Gael fixtures, and git diff --check passed. No Steam upload, server configuration, saved-game mutation or upstream mod edit occurred.

The existing architecture modularizes **attachment behavior, not per-provider UI**: shared/GMAW/Providers/GoM.lua owns GoM/legacy tool and metadata rules and registers EmreFPGoMCompat as an Emre firearm owner routed to the GoM attachment system; shared/GMAW/Providers/Gael.lua owns GGS equipment slots, dependencies, conflicts and native part actions; shared/GMAW/Adapters.lua owns explicit admission/activation/mount-owner routing and shared/GMAW/Model.lua selects a provider and filters candidates; shared/GMAW/Presentation.lua builds provider-filtered common view data. client/GMAW/Window.lua is still the one complete workbench for all families, including its fixed three-column skeleton, union slot order, global diagramRoles/sideRoles, 3D preview, common tool display, and GoM-only tooltip special case. There are no client UI profiles for GoM, Emre or GGS, nor a per-model attachment-marker resolver. Emre is a GoM rules bridge, not an independently implemented provider. GGS/GoM native-action conflict remains explicitly guarded. Any future visual modularity should separate the common window/diagram/preview engine from a per-weapon-owner UI profile, independently of attachmentSystem, because Emre uses the GoM rules but distinct weapon meshes.

## GoM / GGS visual attachment profile routing (2026-10-12)

Supersedes the preceding statement that there are no UI profiles. Added `client/GMAW/UI/Profiles/GoM.lua`, `UI/Profiles/Gael.lua`, `UI/ProfileRegistry.lua` and `UI/AttachmentAnchors.lua`. Native support/provider logic and server authority remain unchanged. `Window.lua` now resolves visual profiles separately from the native attachment system. Thus GoM/GGS use owner-specific native ModelScript attachment-ID aliases while Emre still uses the earlier approximate line positions (not GoM mesh aliases). Missing attachments, invalid/NaN offsets, an unavailable native projector, unfit model geometry or points outside the scene simply omit that slot's leader, preserving the card and click action.

ModelScript attachment local offsets are transformed with the existing fixed preview T*R*S and projected with PZ UI3DScene's real `sceneToUIX/Y`, with horizontal reflection matching the currently observed muzzle-left rendered weapon. No changes were made to the existing 3D camera, model rotation, auto-rotate, native part actions or saved item state. The additional render-time ModelMesh transform is not directly exposed by the Lua attachment metadata, so calculated leader positions are **model-data-based estimates, not verified exact on-mesh attachment hits**. GGS SVD and GoM M4A1 source examples use real native attachment names and offsets, while missing GoM stock points correctly omit stock lines. The small orange endpoint squares remain removed. See `docs/ui-profiles.md` for current mappings and limitations.

The full `scripts/test.ps1` suite (including `tests/ui-anchor-profiles.test.lua`), `scripts/test-gael.ps1 -Installed`, and both current/legacy `scripts/test-installed.ps1` passed. After confirming client and server were shut down, `scripts/install-ui-profiles.ps1` backed up the former workbench Window.lua and copied only five UI Lua files (Window plus four modules) into the local mod and Workshop staging tree. All ten installed copies matched their corresponding source hashes; original GoM/GGS/Emre Workshop caches, source files, saves, presets, server settings and Steam publication remain unchanged. Backup: `evidence/backups/ui-profiles-20261012-213758-466/`. Actual in-game visual alignment needs user testing with GoM M4A1/M16A2 and GGS SVD, especially scope, muzzle, grips and side accessories.
# 2026-10-12: GGS all-slot leader correction

This supersedes the earlier right-camera and screen-reflection explanations
above. The installed engine's `View.Right` is Y=90 degrees, not Y=270. A real
headless `UI3DScene` instance confirms that socket projection already faces left.
The extra screen reflection was therefore removed from the shared projector.
Rifle model orientation, native attachment actions and upstream firearm files
remain unchanged. The later M92FS report confirmed a distinct negative-Z up
axis in 14 exact GoM handgun BODY meshes, in both current and Legacy installs.
Those models alone now receive the matching Y half-turn in rendering, framing
and socket projection; all muzzles and the card layout remain left-facing.

All 346 installed GGS weapons with managed slots and all 2,395 weapon/slot pairs
were checked with generated read-only fixtures. Native metadata has 133 missing
socket pairs (19 RecoilPad, 75 Sling, 39 Misc); existing ordinary parent sockets
have no name-mapping mismatch. The user requested a rear sling display reference,
so `Stock`/`RecoilPad` precede the native `Sling` point; absence still omits the line.
Only the active slot draws an orange leader. Cache invalidation also includes
the scene origin and slot-list identity to prevent stale panel-space endpoints.

Validation: `scripts/test.ps1`, `scripts/test-gael.ps1 -Installed`, including
every displayed-card selection, plus the real native projector at three sizes
and both model-axis signs. Native/model formula difference was below .001 px
before integer rounding. These checks do not establish live mesh-surface
alignment. The current preview does not compose separately installed part meshes.
No Steam upload, server logic edit, or upstream content modification occurred.

## Extensibility audit and no-profile leaders (2026-10-13)

The user reports that the preceding functional/render changes are working in game.
The architecture review is recorded in docs/extensibility-review.md: single-system
weapon bridges are supported, but independent providers still require core changes.
No attachment rules or server code were changed during this review.

Removed the legacy diagram-coordinate fallback for weapons without a visual
profile. Emre and unknown owners keep all cards but draw no leader, selected or
otherwise. This supersedes earlier notes about Emre retaining approximate lines.
Regression tests select every card after switching from a profiled weapon; the
full scripts/test.ps1 suite and git diff --check pass.

Only Window.lua was backed up and copied to the local mod and local Workshop
staging tree. Both copies match source SHA-256
A56C097B8239CCA2F4555C8BCE438B27D88B0510CCB269B55F97DDFE5B9A535B.
The installation record is evidence/no-unverified-leaders-install.json.
No live hot reload or new in-game verification of this final no-line change was
performed. Restart/reload is required for an already running client. No Steam
upload, upstream edit, or server modification occurred.

## Independent provider registration (2026-10-13)

Implemented the bounded plan in docs/provider-extension-plan.md. Adapters now
registers provider systems and ordered slots; Model resolves catalog policies and
permanence from that registry; Batch delegates installed dependency ordering; part
adapters optionally supply planning checks and tool labels. Existing built-in slot
order, GoM permanent-part filtering and GGS preview rules are preserved. Metadata
sets are normalized before common UI/planner use. Registration refreshes the
catalog, without providing runtime mod hot-loading.

The synthetic A/B regression failed on the missing API before implementation,
then passed A-only registration, new-slot presentation, strict native prerequisite
checks, owner/slot rejection, policy filtering, dependency ordering and unchanged
Authority dispatch. Existing source suite and installed GoM current/Legacy and
GGS fixture/native projection checks passed. These are source/engine fixtures,
not live gameplay or proof of a specific new firearm mod's network behavior.

Authority.lua, Server.lua and client Actions.lua remain byte-identical to the
pre-change snapshot. No upstream mod, save, preset or Steam publication changed.
See docs/adding-provider.md for the supported WeaponPart/native-action boundary,
startup registration, native refund/sync responsibilities and coexistence limits.

After checks, backed up and refreshed 28 content files in local install and
Workshop staging. Source/local/staged content hashes agree. Staged workshop.txt
had a byte-format difference without a text diff and was preserved unchanged,
rather than overwritten by source metadata. The accepted poster/preview remains.
No Steam upload or live game session was performed.
