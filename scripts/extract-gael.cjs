// Read-only installed definition evidence. Generated fixtures stay ignored.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const source = process.argv[2];
if (!source) throw Error('Pass the installed Gael 42 directory');
const scripts = path.join(source, 'media/scripts');
const records = {}, hashes = {};
for (const relative of fs.readdirSync(scripts, {recursive:true}).filter(p => p.endsWith('.txt'))) {
  const raw = fs.readFileSync(path.join(scripts, relative), 'utf8');
  hashes[relative] = crypto.createHash('sha256').update(raw).digest('hex');
  const text = raw.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
  const pattern = /\bitem\s+([\w&.-]+)\s*\{/g;
  let match;
  while ((match = pattern.exec(text))) {
    const module = [...text.slice(0,match.index).matchAll(/\bmodule\s+(\w+)/g)].at(-1)?.[1];
    if (!module) continue;
    let depth = 1, end = pattern.lastIndex;
    while (end < text.length && depth) { if (text[end] === '{') depth++; if (text[end] === '}') depth--; end++; }
    const body = text.slice(pattern.lastIndex, end-1); pattern.lastIndex = end;
    const field = name => new RegExp('\\b' + name + '\\s*=\\s*([^,\\r\\n]+)').exec(body)?.[1].trim() || '';
    const fullType = `${module}.${match[1]}`;
    records[fullType] = {fullType, slot:field('PartType'), type:field('ItemType'),
      mounts:field('MountOn').split(';').map(s=>s.replaceAll('"','').trim()).filter(Boolean),
      attach:field('CanAttach'), detach:field('CanDetach')};
  }
}
for (const id of ['Base.M4', 'Base.Accupoint', 'Base.M203_GL']) if (!records[id]) throw Error(`Missing ${id}`);
const quote = JSON.stringify;
let lua = 'gaelRecords = {\n';
for (const [id,record] of Object.entries(records)) {
  lua += `[${quote(id)}]={fullType=${quote(id)},slot=${quote(record.slot)},type=${quote(record.type)},attach=${quote(record.attach)},detach=${quote(record.detach)},mounts={${record.mounts.map(quote).join(',')}}},\n`;
}
fs.mkdirSync(path.join(root,'evidence'),{recursive:true});
fs.writeFileSync(path.join(root,'evidence/gael-fixtures.test.lua'),lua+'}\n');
fs.writeFileSync(path.join(root,'evidence/gael-definitions.json'),JSON.stringify({source, captured:new Date().toISOString(), count:Object.keys(records).length, hashes},null,2));
console.log(`PASS Gael read-only extraction: ${Object.keys(records).length} definitions, ${Object.keys(hashes).length} hashes`);
