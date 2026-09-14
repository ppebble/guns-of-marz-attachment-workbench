// Read-only local interoperability evidence. Extracted IDs/fields stay ignored, not in the mod.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const gom = process.argv[2] || 'C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3722134990/mods/GunsOfMarz/42.16';
const base = path.join(gom, 'media/scripts/MarzWeapons/items');
const records = {}, hashes = {};
for (const relative of fs.readdirSync(base, {recursive:true}).filter(p => p.endsWith('.txt'))) {
  const raw = fs.readFileSync(path.join(base,relative),'utf8');
  hashes[relative] = crypto.createHash('sha256').update(raw).digest('hex');
  const text = raw.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/[^\n]*/g,'');
  const module = /\bmodule\s+(\w+)/.exec(text)?.[1];
  const regex = /\bitem\s+([\w&.-]+)\s*\{/g;
  let match;
  while ((match=regex.exec(text))) {
    let depth=1, end=regex.lastIndex;
    while (end<text.length && depth) { if(text[end]==='{') depth++; if(text[end]==='}') depth--; end++; }
    const body = text.slice(regex.lastIndex,end-1);
    regex.lastIndex=end;
    const field = name => new RegExp('\\b'+name+'\\s*=\\s*([^,\\r\\n]+)').exec(body)?.[1].trim();
    records[`${module}.${match[1]}`] = {
      fullType:`${module}.${match[1]}`, slot:field('PartType') || '', type:field('ItemType') || '',
      mounts:(field('MountOn')||'').split(';').map(s=>s.replaceAll('"','').trim()).filter(Boolean),
      ammo:field('AmmoType') || '', swing:field('SwingAnim') || '',
      models:[...body.matchAll(/\bModelWeaponPart\s*=\s*([^\s,]+)/g)].map(m=>m[1]),
    };
  }
}
const targets=['M4A1','MOSSBERG_590','BENELLI_M4','M92FS','M1911','DEAGLE'];
for (const name of targets) if(!records[`MarzGuns.${name}`]) throw Error(`Missing ${name}`);
const quote = value => JSON.stringify(value);
const array = values => '{'+values.map(quote).join(',')+'}';
const modID = /^id=(.+)$/m.exec(fs.readFileSync(path.join(gom, 'mod.info'), 'utf8'))[1].trim();
let lua = 'installedModID = ' + quote(modID) + '\ninstalledRecords = {\n';
for (const key of Object.keys(records).sort()) {
  const r=records[key];
  lua += `[${quote(key)}]={fullType=${quote(key)},slot=${quote(r.slot)},type=${quote(r.type)},mounts=${array(r.mounts)},models=${array(r.models)},ammo=${quote(r.ammo)},swing=${quote(r.swing)}},\n`;
}
lua+='}\n';
fs.mkdirSync(path.join(root,'evidence'), {recursive:true});
fs.writeFileSync(path.join(root,'evidence/installed-fixtures.test.lua'),lua);
fs.writeFileSync(path.join(root,'evidence/installed-definitions.json'),JSON.stringify({captured:new Date().toISOString(),source:gom,targets:targets.map(n=>records[`MarzGuns.${n}`]),itemCount:Object.keys(records).length,hashes},null,2));
console.log(`PASS read-only extraction: ${Object.keys(records).length} definitions, ${Object.keys(hashes).length} file hashes, ${targets.length} target weapons`);
