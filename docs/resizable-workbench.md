# Personal workbench layout

The workbench opens with the weapon list expanded on first use. Its header arrow
collapses the weapon list and search together; the arrow stays available to reopen
them. Collapsing the list does not clear the selected firearm or search text.

Drag the window's native resize grip to change its size. Drag the vertical
dividers to adjust the weapon, center and attachment columns. The horizontal
center divider changes the preferred balance between the diagram and slot list.

When the center cannot fit readable nodes, the diagram is hidden and the existing
slot list fills the center. There is no second slot list. Extra space is required
before switching back to nodes, reducing flicker near the transition. Selection,
pending choices and the work queue stay intact when the layout changes.

Window position, size, divider ratios and the weapon-list collapsed state are
stored through the game's client-local file API in
`GMAW-layout-v1-player0.ini` (local player indices 0–3 have separate files).
Preferences follow the local game user directory across worlds and servers;
they are not stored in character ModData or synchronized to the server. Invalid
or unsupported settings fall back to defaults. Saved dimensions and positions
are clamped to the current screen when opening. A write failure does not interrupt
the workbench, but preferences cannot persist if its user directory is unwritable.

**Reset layout** restores the initial position, size, proportions and expanded
weapon list. This does not clear the attachment queue or change any firearm.

## Verification boundaries

The Lua harness covers preference round trips, independent local player files,
malformed settings and I/O failures, plus window interactions and layout state.
Native API signatures are checked against the installed game Lua. These checks
do not establish live game rendering or multiplayer session behavior.

For in-game validation, resize a densely populated GoM/GGS firearm with queued
changes, drag each divider, collapse/reopen the weapon list, close/reopen the
workbench, and check a different resolution and larger font. Confirm that the
same slot list remains usable in compact mode and that preview nodes return when
space permits. Confirm preferences after restarting the client. Every client
needs the updated mod files; this feature adds no network messages or server-side
attachment mutations.
