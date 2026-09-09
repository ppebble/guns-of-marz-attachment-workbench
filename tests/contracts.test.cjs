const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const mod = path.join(root, 'Contents/mods/GoMAttachmentWorkbench/42');
const read = p => fs.readFileSync(path.join(mod, p), 'utf8');
assert.match(read('mod.info'), /^require=GunsOfMarz$/m);
assert.match(read('mod.info'), /^loadModAfter=GunsOfMarz$/m);
assert.match(read('mod.info'), /^incompatible=MarzGuns$/m);
function translations(lang) {
  assert.ok(!fs.existsSync(path.join(mod,`media/lua/shared/Translate/${lang}/IGUI_${lang}.txt`)), 'Incorrect old translation filename must not ship');
  return JSON.parse(read(`media/lua/shared/Translate/${lang}/IG_UI.json`));
}
const en = translations('EN'), ko = translations('KO');
assert.deepEqual(Object.keys(en).sort(), Object.keys(ko).sort());
assert.match(ko.IGUI_GMAW_Title, /[가-힣]/, 'Korean encoding retained');
const ui = read('media/lua/client/GMAW/Window.lua');
for (const [,key] of ui.matchAll(/tr\("(\w+)"\)/g)) assert.ok(en[`IGUI_GMAW_${key}`], key);
for (const key of ['Unsupported','Conflict','Dependency','Missing','Tools','Stale','Special','Success','ActionsQueued','Busy','Stopped']) assert.ok(en[`IGUI_GMAW_${key}`]);
for (const [,slot] of read('media/lua/shared/GMAW/Model.lua').split('function M.enabled')[0].matchAll(/"(\w+)"/g)) {
  assert.ok(en[`IGUI_GMAW_Slot_${slot}`], `slot ${slot}`);
}
assert.doesNotMatch(ui, /:attachWeaponPart\(|:detachWeaponPart\(|sendRemoveItemFromContainer\(/, 'client is preview only');
assert.doesNotMatch(ui, /sendClientCommand|GMAWServer/, 'No instant apply protocol');
assert.ok(!fs.existsSync(path.join(mod,'media/lua/server/GMAW/Server.lua')), 'Legacy instant server endpoint removed');
const actions = read('media/lua/client/GMAW/Actions.lua');
for (const name of ['ISInventoryTransferUtil.newInventoryTransferAction','onRemoveUpgradeWeapon','onUpgradeWeapon','ISUpgradeWeapon:new','Events.OnTick.Add(A.tick)']) assert.ok(actions.includes(name));
for (const source of [actions,read('media/lua/shared/GMAW/Batch.lua')]) {
  assert.doesNotMatch(source, /:attachWeaponPart\(|:detachWeaponPart\(|:AddItem\(|:Remove\(|sendRemoveItemFromContainer/, 'Only native timed actions mutate items');
}
assert.doesNotMatch(read('media/lua/shared/GMAW/Model.lua'), /getClassField|getNumClassFields/, 'No debug-only reflection');
const scanner = read('media/lua/shared/GMAW/Sources.lua');
for (const text of ['for dy = -1, 1','for dx = -1, 1','canReachTo','isSafehouseAllowLoot','isLockedToCharacter','canAccessContainer']) assert.ok(scanner.includes(text));
const files = fs.readdirSync(path.join(root,'Contents'), {recursive:true}).map(f => f.replaceAll('\\', '/'));
const ownPoster = 'mods/GoMAttachmentWorkbench/common/poster.png';
assert.ok(files.every(f => !/\.(png|jpg|ogg|fbx|x)$/i.test(f) || f === ownPoster), 'No upstream assets');
function pngSize(file) {
  const bytes = fs.readFileSync(file);
  assert.equal(bytes.subarray(1, 4).toString('ascii'), 'PNG');
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}
assert.deepEqual(pngSize(path.join(root, 'Contents', ownPoster)), { width: 512, height: 512 });
assert.deepEqual(pngSize(path.join(root, 'workshop/preview.png')), { width: 256, height: 256 });
const workshop = fs.readFileSync(path.join(root, 'workshop/workshop.txt'), 'utf8');
assert.match(workshop, /^version=1$/m);
assert.match(workshop, /^title=Guns of Marz: Attachment Workbench$/m);
assert.match(workshop, /sharedfiles\/filedetails\/\?id=3722134990/);
assert.doesNotMatch(workshop, /\{PREVIEW_IMAGE_URL\}/);
console.log(`PASS manifests, source boundary, bounded access, EN/KO ${Object.keys(en).length} keys`);
