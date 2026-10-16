import test from 'node:test';
import assert from 'node:assert/strict';
import {fork} from 'node:child_process';
import {mkdtempSync,readFileSync,writeFileSync,readdirSync,unlinkSync,rmdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
test('Pro survives an operator grant, a new pairing and token renewal',async()=>{
 const directory=mkdtempSync(join(tmpdir(),'draftai-access-'));
 const child=fork(root+'/server/debug-server.mjs',[],{env:{...process.env,DRAFTAI_STATE_DIR:directory,DRAFTAI_PORT:'0',AI_API_KEY:'local-test-no-provider-call',AI_PRO_API_KEY:'local-test-no-provider-call'},silent:true,windowsHide:true});
 try{
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('startup timeout')),4000);child.once('message',m=>{clearTimeout(timer);resolve(m.port);});child.once('exit',()=>reject(new Error('unexpected exit')));});
  const base='http://127.0.0.1:'+port;
  const code=readFileSync(join(directory,'pair-code.txt'),'utf8'),proCode=readFileSync(join(directory,'pro-code.txt'),'utf8');
  const pair=async(body)=>{const r=await fetch(base+'/v1/pair',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});assert.equal(r.status,200);return r.json();};
  const status=async(token)=>{const r=await fetch(base+'/v1/status',{headers:{Authorization:'Bearer '+token}});assert.equal(r.status,200);return r.json();};
  const first=await pair({code});
  assert.equal((await status(first.token)).pro,false);
  const file=join(directory,'usage.json'),state=JSON.parse(readFileSync(file,'utf8'));state.devices[0].pro=true;writeFileSync(file,JSON.stringify(state));
  const second=await pair({code});
  assert.equal((await status(first.token)).pro,true);
  const upgraded=await pair({code:proCode,previousToken:second.token});
  assert.equal((await status(upgraded.token)).pro,true);
  const renewed=await pair({code,previousToken:upgraded.token});
  assert.equal((await status(renewed.token)).pro,true);
  assert.equal(JSON.parse(readFileSync(file,'utf8')).devices.length,2);
 }finally{
  child.kill();await new Promise(resolve=>child.once('exit',resolve));
  for(const name of readdirSync(directory))unlinkSync(join(directory,name));rmdirSync(directory);
 }
});
