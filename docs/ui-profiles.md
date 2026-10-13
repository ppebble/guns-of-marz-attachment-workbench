# Visual attachment profiles (GoM / GGS)

The workbench still uses a single shared `Window.lua`. Attachment rules, part compatibility, native actions and multiplayer authority stay in `shared/GMAW/Providers/*`, while **client-only visual profile maps** now control which native model attachment can receive an informational leader.

## Runtime flow

1. Select firearm; `UI/ProfileRegistry.lua` looks at the *weapon owner's mod ID*, separately from the native `attachmentSystem` used for server actions.
2. The shared model renderer gets the **already loaded ModelScript** from `gun:getStaticModel()`. It does not create or modify an upstream part or model.
3. `UI/AttachmentAnchors.lua` tries exact, case-sensitive attachment names from the owner-specific profile.
4. The fixed `ISUI3DScene` projection `sceneToUIX/Y` converts the script-derived point using the same held-model scale/rotation/translation as the preview. The native Right camera is Y=90 degrees and already produces the left-facing orientation; no additional screen reflection is applied. Points outside the central viewport are rejected.
5. Only the selected clickable callout is connected to its mount origin with an orange leader. No misleading square marker is drawn.
6. If the weapon has no visual profile, the profile has no mapping, the model lacks an attachment, the model could not be fitted, or Java projection fails, the **callout remains clickable but the line is omitted**. Emre and unknown weapon owners have no visual profile and draw no leaders, including for selected cards. Sharing native attachment rules does not imply shared mesh geometry.

## Mapping

- `UI/Profiles/GoM.lua`: `Scope -> scope/rail_up`, `Canon -> canon/muzzle`, `Suppressor -> muzzle/canon`, `Foregrip/Bipod -> rail_down`, `LaserRifle -> rail_left`, `LightRifle -> rail_right` (opposite-side rail fallback), directional rail slots -> their same-named model points. GoM models without a stock or recoil-pad attachment receive **no made-up stock leader**.
- `UI/Profiles/Gael.lua`: `Scope`, `Canon`, `Stock`, `Grip`, `Handguard`, `Mount`, `L_Scope`, `Laser`, `Light`, `RecoilPad`, `Barrel_Shroud`, `Misc` match case-sensitive GGS model IDs. `Sling` uses the explicit rear-reference policy described below. A missing model ID is not guessed. The excluded internal `Clip`, `Hide_Beam`, and stateful `Stool` do not gain special markers.
- `UI/ProfileRegistry.lua`: independent visual profiles for GoM/legacy/GoM-supported vanilla and `GaelGunStore_B42`; **no implicit Emre profile**.

## Accuracy and limits

`ModelScript:getAttachmentById()` supplies a developer-defined model-local attachment transform, not screen coordinates or the actual mesh silhouette. Rendered mesh vertices have a separate transform chain. The native attachment editor places socket offsets through the scene object transform; blindly adding `ModelMesh.transform` to those offsets is incorrect. The installed native `UI3DScene` projector now verifies the camera and object-coordinate contract. This identifies mount origins, not the surface or tip of separately installed attachment meshes; actual game rendering still requires validation.

Native B42 `sceneToUIX/Y` are used instead of inventing framebuffer scale. Projection is cached for the selected model and is recomputed when its fitted dimensions, panel position, or slot-list identity change. There are no new required mods, no redistributed external assets, no changes to inventory actions or authoritative MP validation, and no extra object animation.

## Regression and verification

### GGS full-slot audit and selected-only leaders (2026-10-12)

`scripts/test-gael.ps1 -Installed` regenerates an audit of every installed GGS
firearm and compatible managed slot, tests the actual metadata through the UI
resolver/projector, and runs a headless instance of the installed game's own
`UI3DScene` camera. Generated upstream metadata remains ignored under
`evidence/ggs-anchor-audit/`; only the reader and tests belong to this repository.

The inspected installation has 346 weapons with managed slots, 2,395 weapon/slot
pairs and 31,342 native part links. Every present normal-slot socket agrees with
the native parent attachment name. Missing native sockets occur in RecoilPad
(19 pairs), Sling (75), and Misc (39); they are not repaired with invented points.
Seven definitions without resolved models have no managed slots. Model scale
exceptions and seven dynamic model variants are recorded in the generated report.

Sling is an explicit display exception requested by the user: prefer an existing
`Stock`, then `RecoilPad`, then `Sling` socket as the rear UI reference. This is
not a change to native sling mounting. Seven supported weapons have none of
these reference points, so their sling cards remain without a line.

Only the selected slot draws an orange line; all other cards remain visible and
clickable. Selecting a merged prerequisite highlights its existing parent card.
All source and native projection checks are separate from actual in-game render
verification. The preview still renders the base weapon model, not separately
composed installed attachment meshes.

### GoM handgun up axis

The user confirmed left-facing muzzles and requested only the upside-down handgun
correction. Current and Legacy GoM BODY meshes use negative local Z for physical
up in these exact models: M92FS, M93R, USP, DEAGLE, HIPOWER, P226, M1911, VP70M,
SW629, MP412, RHINO, COLT_SINGLE, PYTHON, DETECTIVE_38. The GoM visual profile
registers only those names. GGS and Emre do not inherit the exception.

Use `Rx(-90) * Ry(180) * Rz(direction)` for those models. The same up sign is
applied to framing and socket projection, preserving the left-facing muzzle.
Installed current/Legacy mesh-node inspection and native JOML tests confirmed
the basis; the native projection regression exercises both forward and up signs.
Actual game rendering after deployment remains a separate check.

`tests/ui-anchor-profiles.test.lua` exercises owner routing, GGS SVD offsets, GoM M4A1 rail aliases, missing/NaN offsets, negative-barrel axis, left-facing muzzle, vertical optic/grip relation, scene cache, and failing native projection. Mock projection alone does not verify actual mesh appearance. `scripts/test.ps1`, `scripts/test-gael.ps1 -Installed`, and `scripts/test-installed.ps1` (current/legacy) verify separate provider/native contracts.

Validate in game with at least one GoM M4A1/M16A2 and one GGS SVD, paying special attention to `Scope`, `Canon`, `Grip/Foregrip`, `Laser`, `Light`, and absent stock attachment. Do not upload to Steam until those tests are satisfactory.
