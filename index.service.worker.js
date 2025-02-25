const CACHE_VERSION="1740448262|4328923",CACHE_PREFIX="GDScript Online-sw-cache-",CACHE_NAME=CACHE_PREFIX+CACHE_VERSION,OFFLINE_URL="index.offline.html",ENSURE_CROSSORIGIN_ISOLATION_HEADERS=!0,CACHED_FILES=["index.html","index.js","index.offline.html","index.icon.png","index.apple-touch-icon.png","index.worker.js","index.audio.worklet.js"],CACHABLE_FILES=["index.wasm","index.pck"],FULL_CACHE=CACHED_FILES.concat(CACHABLE_FILES);self.addEventListener("install",e=>{e.waitUntil(caches.open(CACHE_NAME).then(e=>e.addAll(CACHED_FILES)))}),self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(function(e){return Promise.all(e.filter(e=>e.startsWith(CACHE_PREFIX)&&e!==CACHE_NAME).map(e=>caches.delete(e)))}).then(function(){return"navigationPreload"in self.registration?self.registration.navigationPreload.enable():Promise.resolve()}))});function ensureCrossOriginIsolationHeaders(e){if(e.headers.get("Cross-Origin-Embedder-Policy")==="require-corp"&&e.headers.get("Cross-Origin-Opener-Policy")==="same-origin")return e;const t=new Headers(e.headers);t.set("Cross-Origin-Embedder-Policy","require-corp"),t.set("Cross-Origin-Opener-Policy","same-origin");const n=new Response(e.body,{status:e.status,statusText:e.statusText,headers:t});return n}async function fetchAndCache(e,t,n){let s=await e.preloadResponse;return s==null&&(s=await self.fetch(e.request)),ENSURE_CROSSORIGIN_ISOLATION_HEADERS&&(s=ensureCrossOriginIsolationHeaders(s)),n&&t.put(e.request,s.clone()),s}self.addEventListener("fetch",e=>{const o=e.request.mode==="navigate",i=e.request.url||"",n=e.request.referrer||"",t=n.slice(0,n.lastIndexOf("/")+1),a=i.startsWith(t)?i.replace(t,""):"",s=FULL_CACHE.some(e=>e===a)||t===n&&t.endsWith(CACHED_FILES[0]);o||s?e.respondWith((async()=>{const t=await caches.open(CACHE_NAME);if(o){const n=await Promise.all(FULL_CACHE.map(e=>t.match(e))),o=n.some(e=>e===void 0);if(o)try{const n=await fetchAndCache(e,t,s);return n}catch(e){return console.error("Network error: ",e),caches.match(OFFLINE_URL)}}let n=await t.match(e.request);if(n!=null)return ENSURE_CROSSORIGIN_ISOLATION_HEADERS&&(n=ensureCrossOriginIsolationHeaders(n)),n;const i=await fetchAndCache(e,t,s);return i})()):ENSURE_CROSSORIGIN_ISOLATION_HEADERS&&e.respondWith((async()=>{let t=await fetch(e.request);return t=ensureCrossOriginIsolationHeaders(t),t})())}),self.addEventListener("message",e=>{if(e.origin!==self.origin)return;const n=e.source.id||"",t=e.data||"";self.clients.get(n).then(function(e){if(!e)return;t==="claim"?self.skipWaiting().then(()=>self.clients.claim()):t==="clear"?caches.delete(CACHE_NAME):t==="update"&&self.skipWaiting().then(()=>self.clients.claim()).then(()=>self.clients.matchAll()).then(e=>e.forEach(e=>e.navigate(e.url)))})})