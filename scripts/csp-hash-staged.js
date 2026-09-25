// Hash the staged LF blob, never the Windows working-tree copy.
const {execFileSync}=require('child_process');
const crypto=require('crypto');
const file=process.argv[2]||'Değişiklik Yönetimi MOC/MOC.html';
const html=execFileSync('git',['show',':'+file]).toString('utf8');
const scripts=[...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)];
if(!scripts.length)throw new Error('No inline scripts in '+file);
scripts.forEach((m,i)=>{
  const hash=crypto.createHash('sha256').update(m[1],'utf8').digest('base64');
  process.stdout.write((i+1)+': sha256-'+hash+'\n');
});
