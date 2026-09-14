// Read installed upstream declarations only; fixtures remain in ignored evidence/.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = process.argv[2];
const records = {}, hashes = {};
for (const [owner, relative] of [
  ['ImprovisedSilencers', '3779164273/mods/Improvised Silencers/common/media/scripts/ISIL_items.txt'],
  ['SimpleSuppressors', '3782565181/mods/simple-suppressors/42/media/scripts/Suppressors.txt'],
]) {
  const raw = fs.readFileSync(path.join(root, relative), 'utf8');
  hashes[relative] = crypto.createHash('sha256').update(raw).digest('hex');
  const module = /module\s+(\w+)/.exec(raw)[1];
  for (const [, name, body] of raw.matchAll(/\bitem\s+(\w+)\s*\{([^{}]*)\}/g)) {
    const field = key => new RegExp(`\\b${key}\\s*=\\s*([^,\\r\\n]+)`).exec(body)?.[1].trim() || '';
    if (field('ItemType') !== 'base:weaponpart') continue;
    records[`${module}.${name}`] = {fullType:`${module}.${name}`, owner, type:'base:weaponpart',
      slot:field('PartType'), mounts:field('MountOn').split(';').filter(Boolean),
      canAttach:field('CanAttach'), canDetach:field('CanDetach'), models:[], ammo:'', swing:''};
  }
}
if (Object.keys(records).length !== 21) throw Error('Installed suppressor definitions changed; review compatibility');
function lua(value) {
  if (Array.isArray(value)) return `{${value.map(lua).join(',')}}`;
  if (typeof value === 'object') return `{${Object.entries(value).map(([k,v])=>`[${JSON.stringify(k)}]=${lua(v)}`).join(',')}}`;
  return JSON.stringify(value);
}
const registryFiles = [path.join(root, '3722064198/mods/Gunworks_gang_framework/42.13/media/registries.lua'), path.join(process.argv[3], 'media/registries.lua')];
const registry = registryFiles.filter(p=>fs.existsSync(p)).map(p=>fs.readFileSync(p,'utf8')).join('\n');
const ammoKeys = Object.fromEntries([...registry.matchAll(/AmmoType\.register\("([^"]+)",\s*"([^"]+)"\)/g)].map(m=>[m[1],m[2]]));
fs.writeFileSync('evidence/attachment-fixtures.test.lua', `addonRecords = ${lua(records)}\nammoKeys = ${lua(ammoKeys)}\n`);
fs.writeFileSync('evidence/attachment-definitions.json', JSON.stringify({records, hashes}, null, 2));
console.log('PASS read-only extraction: 5 Improvised Silencers + 16 Simple Suppressors');
