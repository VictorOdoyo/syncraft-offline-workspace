import { readdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, relative, sep } from 'node:path';
import { createHash } from 'node:crypto';

const root = resolve('apps/field/build/web');
async function files(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) result.push(...await files(path));
    else if (!entry.name.endsWith('.map') && !['offline-sw.js','flutter_service_worker.js'].includes(entry.name)) result.push(path);
  }
  return result;
}
const paths = (await files(root)).sort();
const hash = createHash('sha256');
for (const path of paths) hash.update(await readFile(path));
const version = `syncraft-shell-${hash.digest('hex').slice(0,16)}`;
const assets = paths.map(path => '/' + relative(root,path).split(sep).join('/'));
const worker = `const CACHE=${JSON.stringify(version)};
const ASSETS=${JSON.stringify(assets)};
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS))));
self.addEventListener('activate',event=>event.waitUntil(Promise.all([caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('syncraft-shell-')&&k!==CACHE).map(k=>caches.delete(k)))),self.clients.claim()])));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);
 if(event.request.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/api/')||event.request.headers.has('Authorization'))return;
 const key=event.request.mode==='navigate'?'/index.html':url.pathname;
 if(!ASSETS.includes(key))return;
 event.respondWith(caches.open(CACHE).then(async cache=>(await cache.match(key))||fetch(event.request)));
});
`;
await writeFile(resolve(root,'offline-sw.js'),worker);
console.log(`Packaged ${assets.length} offline assets (${version})`);
