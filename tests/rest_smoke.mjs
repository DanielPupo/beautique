import fs from 'node:fs';
import vm from 'node:vm';
const sandbox={window:{}};vm.runInNewContext(fs.readFileSync('dist/config.js','utf8'),sandbox);const c=sandbox.window.BEAUTIQUE_CONFIG;
for(const [route,expected] of [['service_categories?select=slug',200],['services?select=id',200],['appointments?select=id',401],['profiles?select=id',401]]){
 const r=await fetch(c.supabaseUrl+'/rest/v1/'+route,{headers:{apikey:c.supabaseAnonKey},signal:AbortSignal.timeout(10000)});
 const body=await r.json();
 if(route.startsWith('service_categories')&&(r.status!==200||!Array.isArray(body)||body.length!==5))throw new Error('Category REST check failed');
 if(expected===401&&![401,403].includes(r.status))throw new Error('Private route was not denied: '+route);
 if(expected===200&&r.status!==200)throw new Error('Public route failed: '+route);
 console.log('PASS: '+route.split('?')[0]+' HTTP '+r.status);
}
