# UI revision 2026-09-08

- Preserve server protocol and inventory/planner behavior unchanged.
- Fix translation discovery: replace incorrectly named IGUI_LANG.txt with B42 IG_UI.json.
- Lock UI view data with regression tests before replacing rendering.
- Three columns: icon weapon list, supported slot cards showing installed icons and queued previews, selected-slot choices with icon/count/availability.
- Owned usable choices sort first; absent compatible choices remain visible and grey. Arrow/card opens the right selector. Queuing does not claim the part is installed.
- Keep one-weapon cart, automatic prerequisites, and pending-request protections.
- Test translation keys, view-state sorting, slot switching, queue state, and icon rendering calls; rerun existing source and installed-data tests.
- Back up and replace only the local owned mod. No Workshop/save/preset changes.
- User screenshot is a layout reference and evidence of unreadable old UI, not evidence of the new UI. visual-verdict skill is unavailable; record a manual reference assessment without claiming an in-game visual pass.
