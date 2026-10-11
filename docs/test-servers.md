# Attachment systems and manual server tests

## Opening the workbench

The inventory context-menu handler and the workbench's nearby firearm list both use `Model.canOpen`. A firearm must be a supported ranged weapon with an eligible attachment candidate, or a known installed part that the provider permits removing. Carried parts and tools are deliberately not prerequisites for opening the browser: the workbench can discover nearby storage and display missing parts.

Clicking **총기 개조 작업대 열기** opens the shared window with the clicked weapon selected. The left list contains supported nearby firearms; selecting another firearm rebuilds its compatible slots and parts. The right list is the selected weapon's compatible subset, not every part in the provider's catalog. GoM and Gael parts retain their original item identities.

| Firearm / enabled mods | Attachment system | Menu behavior |
| --- | --- | --- |
| GoM + its dependencies | `gom` | Opens for supported candidates/removable parts; GoM tools, rails and optional supported silencers apply. |
| GaelGunStore_B42 only | `gael` | Opens for Gael candidates/removable parts; no GoM or SWMG required. |
| EmreFirearmsPack_B42 + GunsOfMarz + EmreFPGoMCompat | `gom` | Opens only when the bridge actually registers a supported GoM part's MountOn for that Emre firearm. |
| Emre firearm outside the bridge, missing bridge, unsupported gun | None | No workbench entry; also excluded from the workbench firearm list. |

Weapon adapters declare `attachmentSystem`; the firearm's owner need not equal its parts' owner. This preserves the Emre bridge and allows future explicitly registered integrations without treating all foreign weapons as GoM. Unknown owners are not admitted automatically.

The vanilla **무기 개선** menu is more restrictive: it depends on carried, currently usable parts/tools and the destination slot. Workbench visibility therefore is not a literal mirror of that menu. A supported but currently unavailable part remains inspectable here.

## Multiplayer processing

The client builds a plan and schedules inventory transfers and timed actions. At each assembly completion it sends item IDs to the server. The server independently checks the weapon, attachment system, actual part, slot, compatibility, dependency state and working tools in the player's recursive inventory. Native actions perform attachment/removal and inventory synchronization. The client waits for synchronized results; opening the UI itself does not modify items.

Gael's upstream dedicated-server callbacks can accept an attachment despite missing tools, so workbench authority explicitly checks every required tool group before native completion, including removal. Tests must distinguish a mocked command round trip, a real dedicated runtime with unconnected Java player/items, and actual connected-client gameplay.

## Profiles

| Purpose | Server name | Game / UDP ports | Launcher |
| --- | --- | --- | --- |
| Existing GoM environment | `b42211002` | 16261 / 16262 | Existing b42211002 shortcut |
| Existing Emre + GoM bridge | `emre-test` | 16267 / 16268 | Existing emre-test-server shortcut |
| Isolated Gael environment | `gael-test` | 16269 / 16270 | New gael-test-server shortcut |

The Gael profile is created by `scripts/configure-gael-test-server.ps1`. It inherits gameplay/sandbox and connection settings from emre-test, but enables only `GaelGunStore_B42;GoMAttachmentWorkbench`, uses vanilla maps/spawns, a new world/account identity and RCON port 27019. Existing profiles and saves are preserved. It uses the local development workbench; WorkshopItems contains only Gael's 3616176188. First launch may download Gael into the dedicated server cache and initialize a new administrator account.

The same updated workbench files must be present on the dedicated server and every connecting client. Steam searches local Workshop staging before installed Steam mods and `Zomboid/mods`. Here, `C:/Users/ask13/Zomboid/Workshop/GoMAttachmentWorkbench/Contents/mods/GoMAttachmentWorkbench` must also match the development copy. An old staged copy with `require=SWMG` caused the Gael server to reject the workbench as unavailable despite a current copy in `Zomboid/mods`. The configuration script now checks both copies before creating a profile. Synchronize owned mod content with a backup, preserving Workshop description/preview metadata; this is not a Steam upload.

A remote client with only the published Workshop version does not automatically receive these local changes. The user-managed checksum setting on existing profiles is not proof that versions match.

## In-game checklist

1. Start the relevant shortcut and connect to that server's port. Use one large firearm system per test.
2. Right-click a GoM firearm, a Gael firearm, or a bridge-supported Emre firearm. Confirm the clicked gun is selected and only its supported part system is shown.
3. In emre-test, also try an Emre firearm outside the patch's registrations: no workbench menu should appear.
4. Install a normal sight, and a sight needing a mount. Check transferred parts, dependency order, consumed inventory items and final attachment state from the client.
5. Remove/reinstall the part and confirm no duplication, loss or server/client disagreement. Repeat with nearby storage and cancel a queued operation.
6. Remove or break the required screwdriver before completion: the server must refuse the operation without consuming the part.

Gael parent mounts/handguards with installed children must have those children removed first. The entire `Stool` slot is currently excluded; use Gael's own UI for stateful underbarrel parts. GoM + Gael simultaneously remains outside the intended one-system test setup because the upstream global timed-action overrides conflict.
