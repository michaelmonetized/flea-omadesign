import fs from 'node:fs';
import path from 'node:path';
const [input, output] = process.argv.slice(2);
const artwork = JSON.parse(fs.readFileSync(input, 'utf8'));
const directory = path.join(path.dirname(output), '.omabrand/fonts');
fs.mkdirSync(directory, { recursive: true });
let count = 0;
function replace(value) {
  if (Array.isArray(value)) return value.forEach(replace);
  if (!value || typeof value !== 'object') return;
  for (const [key, item] of Object.entries(value)) {
    if (key === 'font' && typeof item === 'string' && fs.existsSync(item)) {
      const bytes = fs.readFileSync(item);
      let hash = 0x6c62272e07bb014262b821756295c58dn;
      for (const byte of bytes) hash = BigInt.asUintN(128, (hash ^ BigInt(byte)) * 0x0000000001000000000000000000013bn);
      const id = hash.toString(16).padStart(32, '0');
      fs.writeFileSync(path.join(directory, id + path.extname(item)), bytes);
      value[key] = 'omatype:' + id;
      count++;
    } else replace(item);
  }
}
replace(artwork);
if (!count) throw new Error('This fixture needs at least one real text layer with an installed font.');
fs.writeFileSync(output, JSON.stringify(artwork));
console.log(`${count} text runs now use archived native project fonts.`);
