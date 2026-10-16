import {ProviderBudget} from './budget.mjs';
import {createServer} from 'node:http';
import {randomBytes,createHash,timingSafeEqual} from 'node:crypto';
import {mkdirSync,readFileSync,writeFileSync,renameSync} from 'node:fs';
import {join} from 'node:path';
import {ServiceError,executeAi,validateTransform,validateFiles} from './service.mjs';

const directory=process.env.DRAFTAI_STATE_DIR;
if(!directory||!process.env.AI_API_KEY)throw new Error('Configure private local credentials and state directory.');
mkdirSync(directory,{recursive:true});const file=join(directory,'usage.json');
let state;try{state=JSON.parse(readFileSync(file,'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;state={devices:[],usage:{}};writeFileSync(file,JSON.stringify(state));}
const persist=()=>{
 // Preserve operator entitlement changes even while a provider request is in flight.
 let devices=[];try{devices=JSON.parse(readFileSync(file,'utf8')).devices;}catch(e){if(e.code!=='ENOENT')throw e;}
 const known=new Map(devices.map(d=>[d.hash,d]));for(const d of state.devices)if(!known.has(d.hash))known.set(d.hash,d);
 state.devices=[...known.values()].filter(d=>d.expires>Date.now());
 writeFileSync(file+'.tmp',JSON.stringify(state));renameSync(file+'.tmp',file);};
const hash=s=>createHash('sha256').update(s).digest('hex');
const safeEqual=(a,b)=>{const x=Buffer.from(a),y=Buffer.from(b);return x.length===y.length&&timingSafeEqual(x,y);};
const fixedModels={model:'openai/gpt-oss-20b',guardModel:'openai/gpt-oss-20b',visionModel:'qwen/qwen3.8-27b'};
const proModel='gpt-5-nano-2025-08-07';
// Private codes survive maintenance restarts until their original expiry.
const codeFile=join(directory,'pair-codes.json');let codes;
try{codes=JSON.parse(readFileSync(codeFile,'utf8'));if(!/^[a-f0-9]{18}$/.test(codes.pairCode)||!/^[a-f0-9]{18}$/.test(codes.proCode)||!Number.isSafeInteger(codes.expires))throw new Error('Invalid pairing state');}catch(e){if(e.code!=='ENOENT')throw e;}
if(!codes||codes.expires<=Date.now()){codes={pairCode:randomBytes(9).toString('hex'),proCode:randomBytes(9).toString('hex'),expires:Date.now()+86400000};writeFileSync(codeFile+'.tmp',JSON.stringify(codes),{mode:0o600});renameSync(codeFile+'.tmp',codeFile);}
const {pairCode,proCode,expires:pairExpires}=codes;
writeFileSync(join(directory,'pair-code.txt'),pairCode,{mode:0o600});
writeFileSync(join(directory,'pro-code.txt'),proCode,{mode:0o600});
// Owner-authorized expansion only on 16 October 2026 in America/Lima.
function limits(){const now=Date.now(),temporary=now>=Date.parse('2026-10-16T05:00:00Z')&&now<Date.parse('2026-10-17T05:00:00Z');return temporary?{calls:120,devices:20,free:10,pro:30}:{calls:60,devices:10,free:2,pro:10};}
const day=()=>new Date().toISOString().slice(0,10);
function usage(){const key=day();if(!state.usage[key]){state.usage={[key]:{provider:0,operations:{}}};persist();}return state.usage[key];}
const budget=new ProviderBudget(directory,{initial:state.usage?.[day()]?.provider??0});
const config={...fixedModels,key:process.env.AI_API_KEY,url:'https://api.groq.com/openai/v1/chat/completions',reserveProvider(){
 budget.max=limits().calls;const count=budget.reserve();const u=usage();u.provider=count;persist();
}};
const bursts=new Map();let inflight=0;
function burst(id,limit){const now=Date.now();const recent=(bursts.get(id)??[]).filter(t=>now-t<60000);if(recent.length>=limit)throw new ServiceError(429,'Espera un minuto antes de reintentar.','rate_limit');recent.push(now);bursts.set(id,recent);if(bursts.size>500){for(const[k,v]of bursts)if(now-v.at(-1)>60000)bursts.delete(k);}}
async function readBody(req,max){const chunks=[];let size=0;for await(const c of req){size+=c.length;if(size>max)throw new ServiceError(413,'Contenido demasiado grande.','input_too_large');chunks.push(c);}try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw new ServiceError(400,'JSON no válido.');}}
const server=createServer(async(req,res)=>{
 res.setHeader('Content-Type','application/json; charset=utf-8');res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');let active=false;
 try{
  if(req.method==='GET'&&req.url==='/'){res.end(JSON.stringify({ready:true,message:'Servidor DraftAI encendido. Usa esta URL en Conectar IA de prueba.'}));return;}
  if(req.method==='GET'&&req.url==='/health'){res.end(JSON.stringify({ready:true,...fixedModels,proModel,proReady:Boolean(process.env.AI_PRO_API_KEY),limits:limits(),temporaryLimitsEnd:"2026-10-17T00:00:00-05:00"}));return;}
  if(!((req.method==='POST'&&['/v1/pair','/v1/transform','/v1/analyze'].includes(req.url))||(req.method==='GET'&&req.url==='/v1/status')))throw new ServiceError(404,'Acción no disponible.');
  if(req.url==='/v1/pair'){
   burst('pair-global',6);const b=await readBody(req,1024);
   const pro=typeof b.code==='string'&&safeEqual(hash(b.code),hash(proCode));
   if(typeof b.code!=='string'||Date.now()>pairExpires||(!pro&&!safeEqual(hash(b.code),hash(pairCode))))throw new ServiceError(401,'Código de conexión no válido o vencido.','invalid_pair');
   // Pairing code stays local, authorizes up to ten test devices, and never enters the APK.
   state.devices=JSON.parse(readFileSync(file,'utf8')).devices;
   const previous=typeof b.previousToken==='string'&&/^[a-f0-9]{64}$/.test(b.previousToken)?state.devices.find(d=>d.expires>Date.now()&&safeEqual(d.hash,hash(b.previousToken))):null;
   if(state.devices.filter(d=>d.expires>Date.now()&&d!==previous).length>=limits().devices)throw new ServiceError(429,'Se alcanzó el máximo de dispositivos de prueba autorizados.');
   const token=randomBytes(32).toString('hex');if(previous){const u=usage();u.operations[hash(token)]=u.operations[previous.hash]??0;}state.devices.push({hash:hash(token),expires:Date.now()+24*3600000,pro:pro||previous?.pro===true});if(previous){previous.expires=0;const disk=JSON.parse(readFileSync(file,'utf8'));disk.devices=disk.devices.filter(d=>d.hash!==previous.hash);writeFileSync(file+'.tmp',JSON.stringify(disk));renameSync(file+'.tmp',file);}persist();
   res.end(JSON.stringify({token,...fixedModels,model:pro||previous?.pro?proModel:fixedModels.model,pro:pro||previous?.pro===true,proModel,expires:Date.now()+24*3600000}));return;
  }
  state.devices=JSON.parse(readFileSync(file,'utf8')).devices;
  const bearer=/^Bearer ([a-f0-9]{64})$/.exec(req.headers.authorization??'')?.[1];
  const device=bearer?state.devices.find(d=>safeEqual(d.hash,hash(bearer))&&d.expires>Date.now()):null;
  if(!device)throw new ServiceError(401,'Conecta este dispositivo para usar la IA de prueba.','pair_required');
  if(req.url==='/v1/status'){
   const current=limits(),limit=device.pro?current.pro:current.free,used=usage().operations[device.hash]??0;
   budget.max=current.calls;
   res.end(JSON.stringify({pro:device.pro,model:device.pro?proModel:fixedModels.model,vision:device.pro&&Boolean(process.env.AI_PRO_API_KEY),remaining:Math.max(0,limit-used),limit,used,globalLimit:current.calls,globalRemaining:budget.remaining(),expires:device.expires}));return;
  }
  burst(device.hash,4);
  if(inflight>=2)throw new ServiceError(429,'El servidor está ocupado. Reintenta más tarde.','busy');
  const body=await readBody(req,req.url==='/v1/analyze'?14500000:60000);
  if(req.url==='/v1/transform')validateTransform(body);else validateFiles(body);
  // Free devices get two transforms per day. Pro must be enabled locally by the operator.
  if(req.url==='/v1/analyze'&&!device.pro)throw new ServiceError(403,'Lectura de imágenes disponible solo en la prueba Pro autorizada.','pro_required');
  if(inflight>=2)throw new ServiceError(429,'El servidor está ocupado.','busy');
  const u=usage(),used=u.operations[device.hash]??0;
  if(used>=(device.pro?limits().pro:limits().free))throw new ServiceError(429,'Límite diario alcanzado.','daily_limit');
  if(u.provider>limits().calls-3)throw new ServiceError(429,'El servidor alcanzó su límite global por hoy.','global_limit');
  u.operations[device.hash]=used+1;persist();inflight++;active=true;
  const abort=new AbortController();res.on('close',()=>{if(!res.writableEnded)abort.abort();});
  if(device.pro&&!process.env.AI_PRO_API_KEY)throw new ServiceError(503,'El servicio Pro todavía no está configurado.','pro_unavailable');
  // The device entitlement is read from trusted local state; the client cannot select a provider or model.
  const selected=device.pro?{...config,key:process.env.AI_PRO_API_KEY,url:'https://api.openai.com/v1/chat/completions',
    model:proModel,visionModel:proModel,guardModel:fixedModels.guardModel,guardKey:config.key,guardUrl:config.url}:config;
  const value=await executeAi(req.url,body,{...selected,signal:abort.signal});if(!res.destroyed)res.end(JSON.stringify(value));
 }catch(e){if(res.destroyed)return;res.writeHead(e instanceof ServiceError?e.status:502);res.end(JSON.stringify({error:e instanceof ServiceError?e.message:'No se pudo completar la solicitud.',code:e instanceof ServiceError?e.code:'provider_unavailable'}));}
 finally{if(active)inflight--;}
});
server.requestTimeout=90000;server.headersTimeout=10000;server.maxConnections=32;
server.listen(Number(process.env.DRAFTAI_PORT??8787),'127.0.0.1',()=>{console.log('DraftAI test gateway ready. Provider keys and request content are never logged.');process.send?.({port:server.address().port});});
