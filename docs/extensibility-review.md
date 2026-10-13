# Attachment-system extensibility review (2026-10-13)

Historical pre-change findings below. The subsequent bounded implementation adds
provider registration, dynamic slots, catalog/removal/dependency callbacks and
optional planning/tool-label hooks. See `adding-provider.md` for the current
contract. Mixed systems, native state conversion and coexistence restrictions
remain outside that implementation.

Current-source review: existing-system bridges are supported; an independent new
attachment system still requires core changes. This review does not change native
actions or server validation.

## A: independent weapons and parts

`Adapters.registerWeapon/registerPart` separate ownership and callbacks, but are
not a complete provider registration API. `Model.lua` fixes providers to GoM/Gael
and fixes their combined slot order; `Presentation.lua` consumes that order.
Unknown attachment systems are rejected. Adding a new provider file alone cannot
make its slots or candidates available.

`Batch.lua` depends on GoM Required/Railing helpers for dependency removal and
restoration. `Attachments.canPlanAttach` special-cases Gael, while Actions and
Authority retain GoM prerequisite/exclusion checks. Gael currently handles its
parent/child restriction safely by refusing parent removal with children present;
this is an existing limitation, not a newly found gameplay regression.

Before implementing an actual A provider, centralize provider registration and
provider slot enumeration, then make planning/removal/dependency policies and
tool presentation explicit provider contracts. Keep native completion and server
revalidation authoritative. Do not generalize native inventory mutation by guess.

## B: weapons sharing an existing part system

An exact weapon owner can register required/excluded mods, an attachmentSystem,
and native MountOn admission. Emre's GoM bridge is the production example;
`tests/provider-matrix.test.lua` also covers a synthetic FutureGaelWeaponBridge.
Part ownership remains independently validated. Matching an item namespace alone
does not admit weapons or parts.

Each weapon currently has one attachmentSystem. `Attachments.sameProvider` requires
equality, so mixing GoM and GGS parts on one weapon is not supported by this contract.
GGS activation blocks all non-Gael mutations through `Model.actionSafe`, protecting
against the known native-action override conflict. Preserve that guard.

Visual profiles correctly follow weapon ownership separately from attachmentSystem.
A bridge may share actions without sharing sockets or mesh orientation. Emre and
unknown owners now retain clickable cards but have no leader lines.

## Contract ambiguities to resolve before wider extension

- Missing attachmentSystem defaults to GoM; require an explicit system for new registrations.
- Adapter `slots` currently filters admission, not the provider-wide candidate slot set.
  Document it as admission-only or implement a consistently enforced weapon slot contract.
- Part adapter routing takes the first active registration for an owner; it has no
  per-part predicate for multiple systems from one owner.
- An adapter with tools gets a Screwdriver label through `Model.toolKey`, even if
  its actual tool differs. Validation and display should share provider tool metadata.
- ProfileRegistry and Window card roles still require edits for new owners/slot layouts.
- Registered native actions must support server-side isValid/complete and native
  inventory sync/refund/state behavior, not merely a client preview callback.

## Evidence and future acceptance checks

The current source suite covers Emre admission, cross-system rejection, a synthetic
Gael bridge, and the existing conflict guard. The new UI regression selects every
card for Emre and an unknown owner after a profiled weapon and verifies zero leader
segments. These checks do not prove arbitrary third-party gameplay integration.

A real independent provider should demonstrate A-only loading without GoM/GGS,
new-slot visibility, candidates and planning, parent replacement or explicit safe
refusal, plus SP and MP native completion/refund/sync. Existing-system bridges need
exact-owner and MountOn positive/negative cases. Mixed-system weapons need a separate
design before they can be advertised as supported.
