# Independent provider extension plan

Scope: make a separately registered firearm/part system usable without editing
the shared workbench for each new provider. Preserve existing GoM, GGS and Emre
behavior, unknown-owner rejection, native actions and authoritative validation.

1. Add a small provider registration contract to the existing shared Adapters
   module. Derive supported systems and ordered slots from registrations.
2. Route catalog eligibility, permanence and replacement dependencies through
   providers; allow part adapters to distinguish planning checks from strict
   native checks and to supply tool labels.
3. Keep unknown visual profiles as cards without lines. Use the existing generic
   card placement for new slots; no new UI framework or per-model guesses.
4. First add an independent-system regression with new slot names, A-only
   activation, a B-to-A bridge, parent/child ordering, late registration and
   unchanged server-side native-action validation. Run it against the old code
   to establish failure, then implement and run existing regression suites.
5. Document one shared integration module and its callback obligations. Do not
   alter Authority.lua, Server.lua, upstream mods, global action-conflict policy,
   user presets or Steam publication.

Non-goals: multiple attachment systems per weapon, runtime hot-loading,
automatic mod discovery, generic native mutation, speculative visual socket maps.
