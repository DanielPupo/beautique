import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd(),dist=path.join(root,'dist');
const prior=fs.readFileSync(path.join(dist,'config.js'),'utf8');
const suppliedUrl=process.env.SUPABASE_URL||'',key=process.env.SUPABASE_ANON_KEY||'';
if(Boolean(suppliedUrl)!==Boolean(key))throw new Error('Configure SUPABASE_URL e SUPABASE_ANON_KEY juntas.');
if(suppliedUrl){
 const u=new URL(suppliedUrl);
 if(u.protocol!=='https:'||u.username||u.password||u.search||u.hash)throw new Error('URL Supabase inválida.');
 if(key.startsWith('sb_secret_'))throw new Error('Chave secreta não pode ser publicada no frontend.');
 if(key.split('.').length===3){let payload;try{payload=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString());}catch{throw new Error('Chave pública inválida.');}if(payload.role!=='anon')throw new Error('Use somente a chave anon/public.');}
 else if(!key.startsWith('sb_publishable_'))throw new Error('Use uma chave anon ou publishable válida.');
 fs.writeFileSync(path.join(dist,'config.js'),'window.BEAUTIQUE_CONFIG = '+JSON.stringify({supabaseUrl:u.origin,supabaseAnonKey:key,whatsappConfirmed:process.env.WHATSAPP_CONFIRMED==='true',bookingMode:'request'})+';\n');
}else if(!prior.includes('window.BEAUTIQUE_CONFIG'))throw new Error('Configuração estática ausente.');
const origin=process.env.SITE_URL||(process.env.VERCEL_PROJECT_PRODUCTION_URL?'https://'+process.env.VERCEL_PROJECT_PRODUCTION_URL:'');
if(origin){const u=new URL(origin);if(u.protocol!=='https:')throw new Error('SITE_URL deve usar HTTPS.');const replace=(dir)=>{for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,entry.name);if(entry.isDirectory())replace(file);else if(/\.(html|xml|txt)$/.test(entry.name)){fs.writeFileSync(file,fs.readFileSync(file,'utf8').replaceAll('https://beautique-itapeva.pupodaniel411.chatgpt.site',u.origin));}}};replace(dist);}
console.log('Arquivos preparados para Vercel. Valores de configuração omitidos do log.');
