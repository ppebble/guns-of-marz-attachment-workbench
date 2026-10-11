# Complete attachment diagram

The old diagram limits itself to six slots (two on small windows) and hides rails and barrel mounts. This loses independently usable Gael slots even though the complete list supports them.

1. Replace the truncation assertions with regressions requiring every supported slot, including prerequisite slots, to remain selectable.
2. Keep the selected firearm above a font-aware card grid. Use complete rows and bounded scrolling for small windows or many slots, with visible row navigation. Keep the existing detailed slot list and attachment actions.
3. Verify grid bounds, distinct hit targets, scrolling to the final slot, and large-font layout with the UI harness. No scanning, refresh, or action-authority changes in this slice.

These are source geometry and interaction checks; live game rendering remains a separate verification step.
