# Spatial firearm diagram

Replace the thumbnail and slot grid with a large central firearm image and asymmetric, role-based callouts. Keep all slots in the existing lower scrolling list. Give scope, stock, muzzle, laser, grip, light and bipod independent callouts; prerequisite rails and mounts compete for remaining space. Selecting an overflow slot promotes it into the diagram.

Callout coordinates describe approximate attachment roles, not per-model bones. Inventory artwork orientation remains an upstream asset limitation. Keep cards outside the firearm rectangle and route orthogonal lines outside it, with only a short endpoint inside its edge. Cache geometry until the view, selection, font or panel size changes.

Before changing the renderer, replace grid-specific regression assertions with spatial contracts: positive central image area, no overlapping cards, separate light/grip/bipod, upper optics and lower accessories, selected overflow promotion, narrow/large-font bounds, hit-target correctness and connector exclusion from the image interior. Export synthetic geometry from the same Lua layout for a clearly labelled preview; in-game rendering remains a separate validation layer.
