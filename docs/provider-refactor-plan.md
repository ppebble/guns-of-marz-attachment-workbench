# Provider refactor plan

Preserve the existing GoM and Emre compatibility contracts while allowing GaelGunstore to use the same workbench without GoM or Gunworks installed.

1. Keep attachment discovery, preview and scheduling shared. Move firearm-family ownership and tool rules into provider modules.
2. Gate WeaponSystems utilities and action hooks behind the GoM family activation; supply vanilla defaults when absent.
3. Register Gael firearms and parts by exact mod ownership and native MountOn declarations. Deny cross-family parts in both candidate discovery and authoritative mutation.
4. Retain GoM optional suppressor and Emre integrations. Do not alter upstream mods or redefine their items.
5. Existing source tests passed before editing. Extend source fixtures for Gael-only, GoM-only, both enabled, and cross-family rejection; separately report local installation and untested live gameplay.

## Attachment-system routing revision

Declare an attachment-system ID on each integration (including Emre-to-GoM). Resolve slot, candidate metadata and part affinity through that system while retaining exact owner, activation and native MountOn admission. Add an early-exit canOpen capability check for eligible attachments or supported removable installed parts, independent of inventory/tools; leave authority admission separate. Preserve coactive native-action safety. Extend existing regression fixtures before claiming completion.
