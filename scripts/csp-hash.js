// Kullanım: node csp-hash.js <html-dosya-yolu>
// İnline <script> (src'siz) bloklarının SHA-256 CSP hash'ini yazdırır.
const fs = require('fs');
const crypto = require('crypto');
const path = process.argv[2];
const html = fs.readFileSync(path, 'utf8');
const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g;
let m, i = 0;
const hashes = [];
while ((m = re.exec(html))) {
  i++;
  const content = m[1];
  const hash = crypto.createHash('sha256').update(content, 'utf8').digest('base64');
  hashes.push(`'sha256-${hash}'`);
  console.log(`#${i} len=${content.length} sha256-${hash}`);
}
console.log('\nscript-src ekle:\n' + hashes.join(' '));
